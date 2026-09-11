package friend

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"strings"
	"time"
)

var (
	ErrNotFound = errors.New("friend request not found")
	ErrConflict = errors.New("friend relationship conflict")
)

type Repository struct{ db *sql.DB }

type User struct {
	ID             uint64 `json:"id"`
	Nickname       string `json:"nickname"`
	AvatarURL      string `json:"avatarUrl,omitempty"`
	Identifier     string `json:"identifier,omitempty"`
	Relationship   string `json:"relationship"`
	ConversationID string `json:"conversationId,omitempty"`
}

type Request struct {
	ID        uint64    `json:"id"`
	UserID    uint64    `json:"userId"`
	Nickname  string    `json:"nickname"`
	AvatarURL string    `json:"avatarUrl,omitempty"`
	CreatedAt time.Time `json:"createdAt"`
}

func NewRepository(db *sql.DB) *Repository { return &Repository{db: db} }

func (r *Repository) Search(ctx context.Context, userID uint64, keyword string) ([]User, error) {
	pattern := "%" + strings.TrimSpace(keyword) + "%"
	rows, err := r.db.QueryContext(ctx, `SELECT id,nickname,COALESCE(avatar_url,''),COALESCE(email,phone,'')
		FROM users WHERE id<>? AND status='active' AND (nickname LIKE ? OR email LIKE ? OR phone LIKE ?)
		ORDER BY nickname LIMIT 20`, userID, pattern, pattern, pattern)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	result := make([]User, 0)
	for rows.Next() {
		var item User
		if err := rows.Scan(&item.ID, &item.Nickname, &item.AvatarURL, &item.Identifier); err != nil {
			return nil, err
		}
		item.Relationship, err = r.relationship(ctx, userID, item.ID)
		if err != nil {
			return nil, err
		}
		if item.Relationship == "friend" {
			item.ConversationID = conversationKey(userID, item.ID)
		}
		result = append(result, item)
	}
	return result, rows.Err()
}

func (r *Repository) List(ctx context.Context, userID uint64) ([]User, error) {
	rows, err := r.db.QueryContext(ctx, `SELECT u.id,u.nickname,COALESCE(u.avatar_url,''),COALESCE(u.email,u.phone,'')
		FROM friendships f JOIN users u ON u.id=f.friend_id
		WHERE f.user_id=? AND u.status='active' ORDER BY u.nickname`, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	result := make([]User, 0)
	for rows.Next() {
		var item User
		if err := rows.Scan(&item.ID, &item.Nickname, &item.AvatarURL, &item.Identifier); err != nil {
			return nil, err
		}
		item.Relationship = "friend"
		item.ConversationID = conversationKey(userID, item.ID)
		result = append(result, item)
	}
	return result, rows.Err()
}

func (r *Repository) Incoming(ctx context.Context, userID uint64) ([]Request, error) {
	rows, err := r.db.QueryContext(ctx, `SELECT fr.id,u.id,u.nickname,COALESCE(u.avatar_url,''),fr.created_at
		FROM friend_requests fr JOIN users u ON u.id=fr.sender_id
		WHERE fr.receiver_id=? AND fr.status='pending' ORDER BY fr.updated_at DESC`, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	result := make([]Request, 0)
	for rows.Next() {
		var item Request
		if err := rows.Scan(&item.ID, &item.UserID, &item.Nickname, &item.AvatarURL, &item.CreatedAt); err != nil {
			return nil, err
		}
		result = append(result, item)
	}
	return result, rows.Err()
}

func (r *Repository) Send(ctx context.Context, senderID, receiverID uint64) error {
	if senderID == receiverID {
		return ErrConflict
	}
	var active bool
	if err := r.db.QueryRowContext(ctx, `SELECT status='active' FROM users WHERE id=?`, receiverID).Scan(&active); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return ErrNotFound
		}
		return err
	}
	if !active {
		return ErrNotFound
	}
	var count int
	if err := r.db.QueryRowContext(ctx, `SELECT COUNT(*) FROM friendships WHERE user_id=? AND friend_id=?`, senderID, receiverID).Scan(&count); err != nil {
		return err
	}
	if count > 0 {
		return ErrConflict
	}
	if err := r.db.QueryRowContext(ctx, `SELECT COUNT(*) FROM friend_requests WHERE sender_id=? AND receiver_id=? AND status='pending'`, receiverID, senderID).Scan(&count); err != nil {
		return err
	}
	if count > 0 {
		return ErrConflict
	}
	_, err := r.db.ExecContext(ctx, `INSERT INTO friend_requests (sender_id,receiver_id,status)
		VALUES (?,?,'pending') ON DUPLICATE KEY UPDATE status='pending',updated_at=NOW(3)`, senderID, receiverID)
	return err
}

func (r *Repository) Respond(ctx context.Context, receiverID, requestID uint64, accept bool) error {
	tx, err := r.db.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()
	var senderID uint64
	if err = tx.QueryRowContext(ctx, `SELECT sender_id FROM friend_requests
		WHERE id=? AND receiver_id=? AND status='pending' FOR UPDATE`, requestID, receiverID).Scan(&senderID); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return ErrNotFound
		}
		return err
	}
	status := "rejected"
	if accept {
		status = "accepted"
	}
	if _, err = tx.ExecContext(ctx, `UPDATE friend_requests SET status=? WHERE id=?`, status, requestID); err != nil {
		return err
	}
	if accept {
		if _, err = tx.ExecContext(ctx, `INSERT IGNORE INTO friendships (user_id,friend_id) VALUES (?,?),(?,?)`, receiverID, senderID, senderID, receiverID); err != nil {
			return err
		}
		key := conversationKey(receiverID, senderID)
		if _, err = tx.ExecContext(ctx, `INSERT INTO conversations (conversation_key,type,title)
			VALUES (?,'private','好友会话') ON DUPLICATE KEY UPDATE conversation_key=VALUES(conversation_key)`, key); err != nil {
			return err
		}
		var conversationID uint64
		if err = tx.QueryRowContext(ctx, `SELECT id FROM conversations WHERE conversation_key=?`, key).Scan(&conversationID); err != nil {
			return err
		}
		if _, err = tx.ExecContext(ctx, `INSERT IGNORE INTO conversation_members (conversation_id,user_id) VALUES (?,?),(?,?)`, conversationID, receiverID, conversationID, senderID); err != nil {
			return err
		}
	}
	return tx.Commit()
}

func (r *Repository) relationship(ctx context.Context, userID, otherID uint64) (string, error) {
	var count int
	if err := r.db.QueryRowContext(ctx, `SELECT COUNT(*) FROM friendships WHERE user_id=? AND friend_id=?`, userID, otherID).Scan(&count); err != nil {
		return "", err
	}
	if count > 0 {
		return "friend", nil
	}
	var senderID, receiverID uint64
	err := r.db.QueryRowContext(ctx, `SELECT sender_id,receiver_id FROM friend_requests
		WHERE ((sender_id=? AND receiver_id=?) OR (sender_id=? AND receiver_id=?)) AND status='pending'
		ORDER BY updated_at DESC LIMIT 1`, userID, otherID, otherID, userID).Scan(&senderID, &receiverID)
	if errors.Is(err, sql.ErrNoRows) {
		return "none", nil
	}
	if err != nil {
		return "", err
	}
	if senderID == userID {
		return "outgoing_pending", nil
	}
	return "incoming_pending", nil
}

func conversationKey(first, second uint64) string {
	if first > second {
		first, second = second, first
	}
	return fmt.Sprintf("friend:%d:%d", first, second)
}
