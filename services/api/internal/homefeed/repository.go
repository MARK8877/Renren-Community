package homefeed

import (
	"context"
	"database/sql"
	"encoding/json"
)

type Repository struct{ db *sql.DB }

func NewRepository(db *sql.DB) *Repository { return &Repository{db: db} }

func (r *Repository) Upsert(ctx context.Context, post Post) error {
	tags, err := json.Marshal(post.Tags)
	if err != nil {
		return err
	}
	_, err = r.db.ExecContext(ctx, `INSERT INTO external_home_posts
		(source, external_id, author, role, content, tags_json, source_url, source_order, published_at, scraped_at)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
		ON DUPLICATE KEY UPDATE author=VALUES(author), role=VALUES(role), content=VALUES(content),
		tags_json=VALUES(tags_json), source_url=VALUES(source_url), source_order=VALUES(source_order),
		published_at=VALUES(published_at), scraped_at=VALUES(scraped_at)`,
		post.Source, post.ExternalID, post.Author, post.Role, post.Content, tags, post.URL,
		post.SourceOrder, post.PublishedAt, post.ScrapedAt)
	return err
}

func (r *Repository) List(ctx context.Context, page, pageSize int) ([]Post, error) {
	if page < 1 {
		page = 1
	}
	if pageSize < 1 || pageSize > 100 {
		pageSize = 20
	}
	rows, err := r.db.QueryContext(ctx, `SELECT id, source, external_id, author, role, content, tags_json, source_url,
		source_order, published_at, scraped_at FROM external_home_posts
		ORDER BY scraped_at DESC, source_order ASC LIMIT ? OFFSET ?`, pageSize, (page-1)*pageSize)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	posts := make([]Post, 0)
	for rows.Next() {
		var post Post
		var tags []byte
		var publishedAt sql.NullTime
		if err := rows.Scan(&post.ID, &post.Source, &post.ExternalID, &post.Author, &post.Role, &post.Content,
			&tags, &post.URL, &post.SourceOrder, &publishedAt, &post.ScrapedAt); err != nil {
			return nil, err
		}
		if err := json.Unmarshal(tags, &post.Tags); err != nil {
			return nil, err
		}
		if publishedAt.Valid {
			value := publishedAt.Time
			post.PublishedAt = &value
		}
		posts = append(posts, post)
	}
	return posts, rows.Err()
}
