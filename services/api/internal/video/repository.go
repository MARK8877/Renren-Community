package video

import (
	"context"
	"database/sql"
	"time"
)

type Repository struct{ db *sql.DB }

func NewRepository(db *sql.DB) *Repository { return &Repository{db: db} }

func (r *Repository) Upsert(ctx context.Context, item Video) error {
	_, err := r.db.ExecContext(ctx, `INSERT INTO platform_videos
		(platform,external_id,title,play_url,like_count,comment_count,share_count,published_at,scraped_at)
		VALUES (?,?,?,?,?,?,?,?,?)
		ON DUPLICATE KEY UPDATE title=VALUES(title),play_url=VALUES(play_url),
		like_count=VALUES(like_count),comment_count=VALUES(comment_count),share_count=VALUES(share_count),
		published_at=VALUES(published_at),scraped_at=VALUES(scraped_at)`,
		item.Platform, item.ExternalID, item.Title, item.PlayURL, item.LikeCount,
		item.CommentCount, item.ShareCount, item.PublishedAt, item.ScrapedAt)
	return err
}

func (r *Repository) List(ctx context.Context, platform string, page, pageSize int) ([]Video, error) {
	if page < 1 {
		page = 1
	}
	if pageSize < 1 || pageSize > 100 {
		pageSize = 20
	}
	offset := (page - 1) * pageSize
	query := `SELECT id,platform,external_id,title,play_url,like_count,comment_count,share_count,published_at,scraped_at
		FROM platform_videos`
	args := []any{}
	if platform != "" {
		query += " WHERE platform=?"
		args = append(args, platform)
	}
	query += " ORDER BY like_count DESC, published_at DESC LIMIT ? OFFSET ?"
	args = append(args, pageSize, offset)
	rows, err := r.db.QueryContext(ctx, query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	result := make([]Video, 0)
	for rows.Next() {
		var item Video
		var publishedAt sql.NullTime
		if err := rows.Scan(&item.ID, &item.Platform, &item.ExternalID, &item.Title, &item.PlayURL,
			&item.LikeCount, &item.CommentCount, &item.ShareCount, &publishedAt, &item.ScrapedAt); err != nil {
			return nil, err
		}
		if publishedAt.Valid {
			published := publishedAt.Time
			item.PublishedAt = &published
		}
		result = append(result, item)
	}
	return result, rows.Err()
}

func (r *Repository) DeleteOlderThan(ctx context.Context, cutoff time.Time) error {
	_, err := r.db.ExecContext(ctx, "DELETE FROM platform_videos WHERE scraped_at<?", cutoff)
	return err
}
