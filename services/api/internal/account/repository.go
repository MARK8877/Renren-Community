package account

import (
	"context"
	"database/sql"
	"errors"
	"strings"
	"time"
)

var ErrNotFound = errors.New("account not found")

type User struct {
	ID                                                            uint64
	Email, Phone, PasswordHash, Nickname, AvatarURL, Role, Status string
}
type Repository struct{ db *sql.DB }

func NewRepository(db *sql.DB) *Repository { return &Repository{db: db} }

func (r *Repository) Create(ctx context.Context, email, phone, passwordHash, nickname string) (User, error) {
	result, err := r.db.ExecContext(ctx, `INSERT INTO users (email,phone,password_hash,nickname) VALUES (NULLIF(?,''),NULLIF(?,''),?,?)`, email, phone, passwordHash, nickname)
	if err != nil {
		return User{}, err
	}
	id, err := result.LastInsertId()
	if err != nil {
		return User{}, err
	}
	return r.ByID(ctx, uint64(id))
}

func (r *Repository) ByIdentifier(ctx context.Context, identifier string) (User, error) {
	query := `SELECT id,COALESCE(email,''),COALESCE(phone,''),password_hash,nickname,COALESCE(avatar_url,''),role,status FROM users WHERE `
	if strings.Contains(identifier, "@") {
		query += "email=?"
	} else {
		query += "phone=?"
	}
	return scan(r.db.QueryRowContext(ctx, query, identifier))
}

func (r *Repository) ByID(ctx context.Context, id uint64) (User, error) {
	return scan(r.db.QueryRowContext(ctx, `SELECT id,COALESCE(email,''),COALESCE(phone,''),password_hash,nickname,COALESCE(avatar_url,''),role,status FROM users WHERE id=?`, id))
}

func (r *Repository) RecordLogin(ctx context.Context, id uint64) error {
	_, err := r.db.ExecContext(ctx, "UPDATE users SET last_login_at=? WHERE id=?", time.Now(), id)
	return err
}

type scanner interface{ Scan(...any) error }

func scan(row scanner) (User, error) {
	var u User
	if err := row.Scan(&u.ID, &u.Email, &u.Phone, &u.PasswordHash, &u.Nickname, &u.AvatarURL, &u.Role, &u.Status); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return User{}, ErrNotFound
		}
		return User{}, err
	}
	return u, nil
}
