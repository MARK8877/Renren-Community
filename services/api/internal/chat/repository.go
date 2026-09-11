package chat

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"strings"
	"time"
)

var ErrNotFound = errors.New("conversation not found")
var ErrForbidden = errors.New("conversation permission denied")
var ErrOwnerCannotLeave = errors.New("group owner cannot leave")
var ErrInvalidOwnerTransfer = errors.New("invalid group owner transfer")

type Repository struct{ db *sql.DB }

type Conversation struct {
	Key             string    `json:"id"`
	Type            string    `json:"type"`
	Title           string    `json:"name"`
	MemberCount     string    `json:"memberCount,omitempty"`
	LastMessage     string    `json:"lastMessage"`
	LastMessageType string    `json:"lastMessageType,omitempty"`
	LastSender      string    `json:"lastSender,omitempty"`
	LastMessageID   uint64    `json:"lastMessageId"`
	UnreadCount     uint64    `json:"unreadCount"`
	UpdatedAt       time.Time `json:"updatedAt"`
	Pinned          bool      `json:"pinned"`
	Muted           bool      `json:"muted"`
}

type Message struct {
	ID               uint64    `json:"id"`
	ConversationID   uint64    `json:"conversationId"`
	SenderID         uint64    `json:"senderId"`
	ReplyToMessageID uint64    `json:"replyToMessageId,omitempty"`
	SenderName       string    `json:"senderName"`
	Type             string    `json:"type"`
	Content          string    `json:"content"`
	CreatedAt        time.Time `json:"createdAt"`
	Recalled         bool      `json:"recalled"`
}

type CreatedGroup struct {
	Key                 string `json:"id"`
	Name                string `json:"name"`
	MemberCount         string `json:"memberCount"`
	AvatarAssetKey      string `json:"avatarAssetKey,omitempty"`
	Announcement        string `json:"announcement,omitempty"`
	JoinMode            string `json:"joinMode,omitempty"`
	MemberInviteEnabled bool   `json:"memberInviteEnabled"`
}

type GroupSettings struct {
	AvatarAssetKey      string
	Announcement        string
	JoinMode            string
	MemberInviteEnabled bool
}

type GroupDetails struct {
	Key                 string `json:"id"`
	Name                string `json:"name"`
	OwnerUserID         uint64 `json:"ownerUserId"`
	AvatarAssetKey      string `json:"avatarAssetKey"`
	Announcement        string `json:"announcement"`
	JoinMode            string `json:"joinMode"`
	MemberInviteEnabled bool   `json:"memberInviteEnabled"`
	Role                string `json:"role"`
}

type GroupMember struct {
	UserID     uint64     `json:"userId"`
	Nickname   string     `json:"nickname"`
	Role       string     `json:"role"`
	MutedUntil *time.Time `json:"mutedUntil,omitempty"`
}

type JoinRequest struct {
	ID              uint64    `json:"id"`
	ApplicantUserID uint64    `json:"applicantUserId"`
	ApplicantName   string    `json:"applicantName"`
	InviterUserID   uint64    `json:"inviterUserId,omitempty"`
	CreatedAt       time.Time `json:"createdAt"`
}

type defaultConversation struct {
	key, kind, title, memberCount string
	messages                      []seedMessage
}

type seedMessage struct{ sender, kind, content string }

var defaults = []defaultConversation{
	{key: "group-product", kind: "group", title: "产品设计交流社区", memberCount: "18,420", messages: []seedMessage{
		{sender: "Luna", kind: "text", content: "欢迎大家交流产品设计与社区体验。"},
		{sender: "阿杰", kind: "text", content: "有人参加本周线上讨论吗？"},
	}},
	{key: "luna", kind: "private", title: "Luna Design", messages: []seedMessage{
		{sender: "Luna Design", kind: "text", content: "你好，我很喜欢你分享的社区设计思路。"},
		{sender: "Luna Design", kind: "content", content: "社区产品如何把内容浏览变成真实关系？"},
		{sender: "Luna Design", kind: "text", content: "这版交互思路很清晰，可以继续完善"},
	}},
	{key: "xiaoyu", kind: "private", title: "小宇", messages: []seedMessage{
		{sender: "小宇", kind: "text", content: "你好，可以认识一下吗？"},
		{sender: "小宇", kind: "text", content: "好的，稍后发给你"},
	}},
	{key: "group-ai", kind: "group", title: "AI 视频创作者交流群", memberCount: "2,856", messages: []seedMessage{
		{sender: "Kevin AI", kind: "text", content: "欢迎大家加入！这里可以交流 AI 视频创作流程。"},
		{sender: "小宇", kind: "text", content: "刚试了视频里的方法，生成效率提升很多。"},
		{sender: "Luna", kind: "image", content: "AI 视频工作流示例"},
		{sender: "Kevin AI", kind: "content", content: "今晚分享完整工作流"},
	}},
	{key: "group-event", kind: "group", title: "活动运营共创群", memberCount: "6,320", messages: []seedMessage{
		{sender: "活动实验室", kind: "text", content: "欢迎一起讨论活动策划和社区运营。"},
	}},
	{key: "group-creators", kind: "group", title: "创作者交流群", memberCount: "9,680", messages: []seedMessage{
		{sender: "群助手", kind: "text", content: "欢迎创作者分享经验、互相交流。"},
	}},
}

func NewRepository(db *sql.DB) *Repository { return &Repository{db: db} }

func (r *Repository) CreateGroup(ctx context.Context, userID uint64, key, name string) (CreatedGroup, error) {
	return r.CreateGroupWithSettings(ctx, userID, key, name, GroupSettings{
		JoinMode:            "direct",
		MemberInviteEnabled: true,
	})
}

func (r *Repository) CreateGroupWithSettings(ctx context.Context, userID uint64, key, name string, settings GroupSettings) (CreatedGroup, error) {
	tx, err := r.db.BeginTx(ctx, nil)
	if err != nil {
		return CreatedGroup{}, err
	}
	defer tx.Rollback()
	result, err := tx.ExecContext(ctx, `INSERT INTO conversations
		(conversation_key,type,title,member_count,owner_user_id,avatar_asset_key,announcement,join_mode,member_invite_enabled)
		VALUES (?,'group',?,'1',?,?,?,?,?)`, key, name, userID, settings.AvatarAssetKey,
		settings.Announcement, settings.JoinMode, settings.MemberInviteEnabled)
	if err != nil {
		return CreatedGroup{}, err
	}
	conversationID, err := result.LastInsertId()
	if err != nil {
		return CreatedGroup{}, err
	}
	if _, err = tx.ExecContext(ctx, `INSERT INTO conversation_members (conversation_id,user_id,role,last_read_message_id) VALUES (?,?,'owner',0)`, conversationID, userID); err != nil {
		return CreatedGroup{}, err
	}
	if err = tx.Commit(); err != nil {
		return CreatedGroup{}, err
	}
	return CreatedGroup{Key: key, Name: name, MemberCount: "1", AvatarAssetKey: settings.AvatarAssetKey,
		Announcement: settings.Announcement, JoinMode: settings.JoinMode, MemberInviteEnabled: settings.MemberInviteEnabled}, nil
}

func (r *Repository) EnsureDefaults(ctx context.Context, userID uint64) error {
	tx, err := r.db.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()
	for _, item := range defaults {
		conversationKey := storageKey(item.key, userID)
		_, err = tx.ExecContext(ctx, `INSERT INTO conversations (conversation_key,type,title,member_count)
			VALUES (?,?,?,?) ON DUPLICATE KEY UPDATE title=VALUES(title),member_count=VALUES(member_count)`, conversationKey, item.kind, item.title, item.memberCount)
		if err != nil {
			return err
		}
		var conversationID uint64
		if err = tx.QueryRowContext(ctx, `SELECT id FROM conversations WHERE conversation_key=?`, conversationKey).Scan(&conversationID); err != nil {
			return err
		}
		if _, err = tx.ExecContext(ctx, `INSERT IGNORE INTO conversation_members (conversation_id,user_id) VALUES (?,?)`, conversationID, userID); err != nil {
			return err
		}
		if _, err = tx.ExecContext(ctx, `UPDATE conversations SET owner_user_id=COALESCE(owner_user_id,?) WHERE id=? AND type='group'`, userID, conversationID); err != nil {
			return err
		}
		if _, err = tx.ExecContext(ctx, `UPDATE conversation_members SET role='owner' WHERE conversation_id=? AND user_id=? AND EXISTS (SELECT 1 FROM conversations WHERE id=? AND type='group')`, conversationID, userID, conversationID); err != nil {
			return err
		}
		for index, message := range item.messages {
			clientID := fmt.Sprintf("seed:%s:%d", item.key, index+1)
			if _, err = tx.ExecContext(ctx, `INSERT IGNORE INTO messages
				(conversation_id,sender_id,sender_name,message_type,content,client_message_id,created_at)
				VALUES (?,NULL,?,?,?,?,DATE_SUB(NOW(3), INTERVAL ? MINUTE))`, conversationID, message.sender, message.kind, message.content, clientID, len(item.messages)-index); err != nil {
				return err
			}
		}
	}
	return tx.Commit()
}

func (r *Repository) ListConversations(ctx context.Context, userID uint64) ([]Conversation, error) {
	rows, err := r.db.QueryContext(ctx, `SELECT c.conversation_key,c.type,
		CASE WHEN c.type='private' AND c.conversation_key LIKE 'friend:%' THEN COALESCE(
			(SELECT u.nickname FROM conversation_members other
			 JOIN users u ON u.id=other.user_id
			 WHERE other.conversation_id=c.id AND other.user_id<>? LIMIT 1),c.title)
		ELSE c.title END,c.member_count,
		COALESCE(last_message.id,0),COALESCE(last_message.sender_name,''),COALESCE(last_message.message_type,''),
		COALESCE(last_message.content,''),COALESCE(last_message.created_at,c.updated_at),cm.pinned,cm.muted,
		(SELECT COUNT(*) FROM messages unread WHERE unread.conversation_id=c.id
		 AND unread.id>cm.last_read_message_id AND (unread.sender_id IS NULL OR unread.sender_id<>?))
		FROM conversation_members cm
		JOIN conversations c ON c.id=cm.conversation_id
		LEFT JOIN messages last_message ON last_message.id=(SELECT MAX(latest.id) FROM messages latest WHERE latest.conversation_id=c.id)
		WHERE cm.user_id=? ORDER BY cm.pinned DESC,COALESCE(last_message.created_at,c.updated_at) DESC`, userID, userID, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var result []Conversation
	for rows.Next() {
		var item Conversation
		if err := rows.Scan(&item.Key, &item.Type, &item.Title, &item.MemberCount, &item.LastMessageID, &item.LastSender, &item.LastMessageType, &item.LastMessage, &item.UpdatedAt, &item.Pinned, &item.Muted, &item.UnreadCount); err != nil {
			return nil, err
		}
		if item.Type == "private" {
			item.Key, _, _ = strings.Cut(item.Key, ":")
		}
		result = append(result, item)
	}
	return result, rows.Err()
}

func (r *Repository) ListMessages(ctx context.Context, userID uint64, key string, beforeID uint64, limit int) ([]Message, error) {
	conversationID, err := r.memberConversationID(ctx, userID, key)
	if err != nil {
		return nil, err
	}
	query := `SELECT id,conversation_id,COALESCE(sender_id,0),sender_name,message_type,content,
		COALESCE(reply_to_message_id,0),created_at,recalled_at IS NOT NULL
		FROM messages WHERE conversation_id=?`
	args := []any{conversationID}
	if beforeID > 0 {
		query += " AND id<?"
		args = append(args, beforeID)
	}
	query += " ORDER BY id DESC LIMIT ?"
	args = append(args, limit)
	rows, err := r.db.QueryContext(ctx, query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var reversed []Message
	for rows.Next() {
		var item Message
		if err := rows.Scan(&item.ID, &item.ConversationID, &item.SenderID, &item.SenderName, &item.Type, &item.Content, &item.ReplyToMessageID, &item.CreatedAt, &item.Recalled); err != nil {
			return nil, err
		}
		reversed = append(reversed, item)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	result := make([]Message, len(reversed))
	for index := range reversed {
		result[len(reversed)-1-index] = reversed[index]
	}
	return result, nil
}

func (r *Repository) CreateMessage(ctx context.Context, userID uint64, key, senderName, messageType, content, clientMessageID string, replyTo uint64) (Message, error) {
	conversationID, err := r.memberConversationID(ctx, userID, key)
	if err != nil {
		return Message{}, err
	}
	var reply any
	if replyTo > 0 {
		var count int
		if err := r.db.QueryRowContext(ctx, `SELECT COUNT(*) FROM messages WHERE id=? AND conversation_id=?`, replyTo, conversationID).Scan(&count); err != nil || count == 0 {
			return Message{}, ErrNotFound
		}
		reply = replyTo
	}
	result, err := r.db.ExecContext(ctx, `INSERT INTO messages
		(conversation_id,sender_id,sender_name,message_type,content,reply_to_message_id,client_message_id)
		VALUES (?,?,?,?,?,NULLIF(?,0),NULLIF(?,''))`, conversationID, userID, senderName, messageType, content, reply, clientMessageID)
	if err != nil {
		if clientMessageID != "" {
			return r.byClientID(ctx, conversationID, clientMessageID)
		}
		return Message{}, err
	}
	id, err := result.LastInsertId()
	if err != nil {
		return Message{}, err
	}
	return r.byID(ctx, uint64(id))
}

func (r *Repository) MarkRead(ctx context.Context, userID uint64, key string, messageID uint64) error {
	conversationID, err := r.memberConversationID(ctx, userID, key)
	if err != nil {
		return err
	}
	var count int
	if err := r.db.QueryRowContext(ctx, `SELECT COUNT(*) FROM messages WHERE conversation_id=? AND id=?`, conversationID, messageID).Scan(&count); err != nil {
		return err
	}
	if count == 0 {
		return ErrNotFound
	}
	_, err = r.db.ExecContext(ctx, `UPDATE conversation_members SET last_read_message_id=GREATEST(last_read_message_id,?) WHERE conversation_id=? AND user_id=?`, messageID, conversationID, userID)
	return err
}

func (r *Repository) MarkAllRead(ctx context.Context, userID uint64) error {
	_, err := r.db.ExecContext(ctx, `UPDATE conversation_members cm SET last_read_message_id=COALESCE(
		(SELECT MAX(m.id) FROM messages m WHERE m.conversation_id=cm.conversation_id),0) WHERE cm.user_id=?`, userID)
	return err
}

func (r *Repository) GetGroup(ctx context.Context, userID uint64, key string) (GroupDetails, error) {
	var result GroupDetails
	err := r.db.QueryRowContext(ctx, `SELECT c.conversation_key,c.title,c.owner_user_id,c.avatar_asset_key,
		c.announcement,c.join_mode,c.member_invite_enabled,cm.role
		FROM conversations c JOIN conversation_members cm ON cm.conversation_id=c.id
		WHERE c.conversation_key=? AND c.type='group' AND cm.user_id=?`, storageKey(key, userID), userID).
		Scan(&result.Key, &result.Name, &result.OwnerUserID, &result.AvatarAssetKey, &result.Announcement,
			&result.JoinMode, &result.MemberInviteEnabled, &result.Role)
	if errors.Is(err, sql.ErrNoRows) {
		return GroupDetails{}, ErrNotFound
	}
	return result, err
}

func (r *Repository) ListMembers(ctx context.Context, userID uint64, key string) ([]GroupMember, error) {
	conversationID, err := r.memberConversationID(ctx, userID, key)
	if err != nil {
		return nil, err
	}
	rows, err := r.db.QueryContext(ctx, `SELECT cm.user_id,u.nickname,cm.role,cm.muted_until
		FROM conversation_members cm JOIN users u ON u.id=cm.user_id
		WHERE cm.conversation_id=? ORDER BY FIELD(cm.role,'owner','admin','member'),u.nickname`, conversationID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var result []GroupMember
	for rows.Next() {
		var item GroupMember
		if err := rows.Scan(&item.UserID, &item.Nickname, &item.Role, &item.MutedUntil); err != nil {
			return nil, err
		}
		result = append(result, item)
	}
	return result, rows.Err()
}

func (r *Repository) UpdateGroup(ctx context.Context, userID uint64, key string, settings GroupSettings) error {
	conversationID, role, err := r.memberRole(ctx, userID, key)
	if err != nil {
		return err
	}
	if role != "owner" && role != "admin" {
		return ErrForbidden
	}
	if settings.JoinMode != "direct" && settings.JoinMode != "approval" {
		return fmt.Errorf("invalid join mode")
	}
	if role == "admin" {
		_, err = r.db.ExecContext(ctx, `UPDATE conversations SET announcement=? WHERE id=?`, settings.Announcement, conversationID)
		return err
	}
	_, err = r.db.ExecContext(ctx, `UPDATE conversations SET avatar_asset_key=?,announcement=?,join_mode=?,member_invite_enabled=? WHERE id=?`,
		settings.AvatarAssetKey, settings.Announcement, settings.JoinMode, settings.MemberInviteEnabled, conversationID)
	return err
}

func (r *Repository) InviteMember(ctx context.Context, actorID uint64, key string, targetID uint64) error {
	conversationID, role, err := r.memberRole(ctx, actorID, key)
	if err != nil {
		return err
	}
	var inviteEnabled bool
	var joinMode string
	if err = r.db.QueryRowContext(ctx, `SELECT member_invite_enabled,join_mode FROM conversations WHERE id=?`, conversationID).Scan(&inviteEnabled, &joinMode); err != nil {
		return err
	}
	if role == "member" && !inviteEnabled {
		return ErrForbidden
	}
	var exists int
	if err = r.db.QueryRowContext(ctx, `SELECT COUNT(*) FROM conversation_members WHERE conversation_id=? AND user_id=?`, conversationID, targetID).Scan(&exists); err != nil {
		return err
	}
	if exists > 0 {
		return nil
	}
	if joinMode == "approval" {
		_, err = r.db.ExecContext(ctx, `INSERT INTO group_join_requests (conversation_id,applicant_user_id,inviter_user_id) VALUES (?,?,?)`, conversationID, targetID, actorID)
		return err
	}
	_, err = r.db.ExecContext(ctx, `INSERT INTO conversation_members (conversation_id,user_id,role) VALUES (?,?,'member')`, conversationID, targetID)
	return err
}

func (r *Repository) SetMemberRole(ctx context.Context, actorID uint64, key string, targetID uint64, role string) error {
	conversationID, actorRole, err := r.memberRole(ctx, actorID, key)
	if err != nil {
		return err
	}
	if actorRole != "owner" || (role != "admin" && role != "member") {
		return ErrForbidden
	}
	_, err = r.db.ExecContext(ctx, `UPDATE conversation_members SET role=? WHERE conversation_id=? AND user_id=? AND role<>'owner'`, role, conversationID, targetID)
	return err
}

func (r *Repository) SetMemberMute(ctx context.Context, actorID uint64, key string, targetID uint64, until *time.Time) error {
	conversationID, actorRole, err := r.memberRole(ctx, actorID, key)
	if err != nil {
		return err
	}
	var targetRole string
	if err = r.db.QueryRowContext(ctx, `SELECT role FROM conversation_members WHERE conversation_id=? AND user_id=?`, conversationID, targetID).Scan(&targetRole); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return ErrNotFound
		}
		return err
	}
	if targetRole != "member" || (actorRole != "owner" && actorRole != "admin") {
		return ErrForbidden
	}
	_, err = r.db.ExecContext(ctx, `UPDATE conversation_members SET muted_until=? WHERE conversation_id=? AND user_id=?`, until, conversationID, targetID)
	return err
}

func (r *Repository) RemoveMember(ctx context.Context, actorID uint64, key string, targetID uint64) error {
	conversationID, actorRole, err := r.memberRole(ctx, actorID, key)
	if err != nil {
		return err
	}
	var targetRole string
	if err = r.db.QueryRowContext(ctx, `SELECT role FROM conversation_members WHERE conversation_id=? AND user_id=?`, conversationID, targetID).Scan(&targetRole); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return ErrNotFound
		}
		return err
	}
	if targetRole != "member" || (actorRole != "owner" && actorRole != "admin") {
		return ErrForbidden
	}
	_, err = r.db.ExecContext(ctx, `DELETE FROM conversation_members WHERE conversation_id=? AND user_id=?`, conversationID, targetID)
	return err
}

func (r *Repository) LeaveGroup(ctx context.Context, userID uint64, key string) error {
	conversationID, role, err := r.memberRole(ctx, userID, key)
	if err != nil {
		return err
	}
	if role == "owner" {
		return ErrOwnerCannotLeave
	}
	_, err = r.db.ExecContext(ctx, `DELETE FROM conversation_members WHERE conversation_id=? AND user_id=?`, conversationID, userID)
	return err
}

func (r *Repository) TransferOwner(ctx context.Context, actorID uint64, key string, targetID uint64) error {
	tx, err := r.db.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()
	var conversationID uint64
	var actorRole string
	err = tx.QueryRowContext(ctx, `SELECT c.id,cm.role FROM conversations c JOIN conversation_members cm ON cm.conversation_id=c.id
		WHERE c.conversation_key=? AND c.type='group' AND cm.user_id=? FOR UPDATE`, storageKey(key, actorID), actorID).
		Scan(&conversationID, &actorRole)
	if errors.Is(err, sql.ErrNoRows) {
		return ErrNotFound
	}
	if err != nil {
		return err
	}
	if actorRole != "owner" || targetID == actorID {
		return ErrForbidden
	}
	var targetRole string
	err = tx.QueryRowContext(ctx, `SELECT role FROM conversation_members WHERE conversation_id=? AND user_id=? FOR UPDATE`, conversationID, targetID).Scan(&targetRole)
	if errors.Is(err, sql.ErrNoRows) {
		return ErrNotFound
	}
	if err != nil {
		return err
	}
	if targetRole == "owner" {
		return ErrInvalidOwnerTransfer
	}
	if _, err = tx.ExecContext(ctx, `UPDATE conversations SET owner_user_id=? WHERE id=?`, targetID, conversationID); err != nil {
		return err
	}
	if _, err = tx.ExecContext(ctx, `UPDATE conversation_members SET role='member' WHERE conversation_id=? AND user_id=?`, conversationID, actorID); err != nil {
		return err
	}
	if _, err = tx.ExecContext(ctx, `UPDATE conversation_members SET role='owner' WHERE conversation_id=? AND user_id=?`, conversationID, targetID); err != nil {
		return err
	}
	return tx.Commit()
}

func (r *Repository) ListJoinRequests(ctx context.Context, actorID uint64, key string) ([]JoinRequest, error) {
	conversationID, role, err := r.memberRole(ctx, actorID, key)
	if err != nil {
		return nil, err
	}
	if role != "owner" {
		return nil, ErrForbidden
	}
	rows, err := r.db.QueryContext(ctx, `SELECT jr.id,jr.applicant_user_id,u.nickname,COALESCE(jr.inviter_user_id,0),jr.created_at
		FROM group_join_requests jr JOIN users u ON u.id=jr.applicant_user_id
		WHERE jr.conversation_id=? AND jr.status='pending' ORDER BY jr.created_at`, conversationID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	result := make([]JoinRequest, 0)
	for rows.Next() {
		var item JoinRequest
		if err := rows.Scan(&item.ID, &item.ApplicantUserID, &item.ApplicantName, &item.InviterUserID, &item.CreatedAt); err != nil {
			return nil, err
		}
		result = append(result, item)
	}
	return result, rows.Err()
}

func (r *Repository) ResolveJoinRequest(ctx context.Context, actorID uint64, key string, requestID uint64, accept bool) error {
	conversationID, role, err := r.memberRole(ctx, actorID, key)
	if err != nil {
		return err
	}
	if role != "owner" {
		return ErrForbidden
	}
	tx, err := r.db.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()
	var applicantID uint64
	if err = tx.QueryRowContext(ctx, `SELECT applicant_user_id FROM group_join_requests WHERE id=? AND conversation_id=? AND status='pending' FOR UPDATE`, requestID, conversationID).Scan(&applicantID); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return ErrNotFound
		}
		return err
	}
	status := "rejected"
	if accept {
		status = "accepted"
		if _, err = tx.ExecContext(ctx, `INSERT IGNORE INTO conversation_members (conversation_id,user_id,role) VALUES (?,?,'member')`, conversationID, applicantID); err != nil {
			return err
		}
	}
	if _, err = tx.ExecContext(ctx, `UPDATE group_join_requests SET status=?,handled_at=NOW(3) WHERE id=?`, status, requestID); err != nil {
		return err
	}
	return tx.Commit()
}

func (r *Repository) memberRole(ctx context.Context, userID uint64, key string) (uint64, string, error) {
	var conversationID uint64
	var role string
	err := r.db.QueryRowContext(ctx, `SELECT c.id,cm.role FROM conversations c JOIN conversation_members cm ON cm.conversation_id=c.id
		WHERE c.conversation_key=? AND c.type='group' AND cm.user_id=?`, storageKey(key, userID), userID).Scan(&conversationID, &role)
	if errors.Is(err, sql.ErrNoRows) {
		return 0, "", ErrNotFound
	}
	return conversationID, role, err
}

func (r *Repository) memberConversationID(ctx context.Context, userID uint64, key string) (uint64, error) {
	var id uint64
	err := r.db.QueryRowContext(ctx, `SELECT c.id FROM conversations c JOIN conversation_members cm ON cm.conversation_id=c.id WHERE c.conversation_key=? AND cm.user_id=?`, storageKey(key, userID), userID).Scan(&id)
	if errors.Is(err, sql.ErrNoRows) {
		return 0, ErrNotFound
	}
	return id, err
}

func storageKey(key string, userID uint64) string {
	if key == "luna" || key == "xiaoyu" {
		return fmt.Sprintf("%s:%d", key, userID)
	}
	return key
}

func (r *Repository) byID(ctx context.Context, id uint64) (Message, error) {
	var item Message
	err := r.db.QueryRowContext(ctx, `SELECT id,conversation_id,COALESCE(sender_id,0),sender_name,message_type,content,COALESCE(reply_to_message_id,0),created_at,recalled_at IS NOT NULL FROM messages WHERE id=?`, id).
		Scan(&item.ID, &item.ConversationID, &item.SenderID, &item.SenderName, &item.Type, &item.Content, &item.ReplyToMessageID, &item.CreatedAt, &item.Recalled)
	if errors.Is(err, sql.ErrNoRows) {
		return Message{}, ErrNotFound
	}
	return item, err
}

func (r *Repository) byClientID(ctx context.Context, conversationID uint64, clientID string) (Message, error) {
	var id uint64
	if err := r.db.QueryRowContext(ctx, `SELECT id FROM messages WHERE conversation_id=? AND client_message_id=?`, conversationID, clientID).Scan(&id); err != nil {
		return Message{}, err
	}
	return r.byID(ctx, id)
}
