package shortdrama

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"
	"time"
)

type Repository struct{ db *sql.DB }

var ErrNotFound = errors.New("short drama not found")

func NewRepository(db *sql.DB) *Repository { return &Repository{db: db} }

func (r *Repository) Upsert(ctx context.Context, drama Drama, scrapedAt time.Time) error {
	episodes, err := drama.episodesJSON()
	if err != nil {
		return err
	}
	_, err = r.db.ExecContext(ctx, `INSERT INTO short_dramas
		(source_id,source_name,external_id,name,subtitle,remarks,poster_url,year,area,language,
		 actors,director,score,type_name,class_name,duration,blurb,content,total_episodes,
		 update_time,episodes_json,scraped_at)
		VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
		ON DUPLICATE KEY UPDATE source_name=VALUES(source_name),name=VALUES(name),subtitle=VALUES(subtitle),
		remarks=VALUES(remarks),poster_url=VALUES(poster_url),year=VALUES(year),area=VALUES(area),
		language=VALUES(language),actors=VALUES(actors),director=VALUES(director),score=VALUES(score),
		type_name=VALUES(type_name),class_name=VALUES(class_name),duration=VALUES(duration),
		blurb=VALUES(blurb),content=VALUES(content),total_episodes=VALUES(total_episodes),
		update_time=VALUES(update_time),episodes_json=VALUES(episodes_json),scraped_at=VALUES(scraped_at)`,
		drama.SourceID, drama.SourceName, drama.ExternalID, drama.Name, drama.Subtitle, drama.Remarks,
		drama.PosterURL, drama.Year, drama.Area, drama.Language, drama.Actors, drama.Director,
		drama.Score, drama.Type, drama.Class, drama.Duration, drama.Blurb, drama.Content,
		drama.TotalEpisodes, drama.UpdateTime, episodes, scrapedAt)
	return err
}

func (r *Repository) List(ctx context.Context, page, pageSize int) ([]DramaRecord, error) {
	page, pageSize = normalizePage(page, pageSize)
	offset := (page - 1) * pageSize
	rows, err := r.db.QueryContext(ctx, `SELECT id,source_id,source_name,external_id,name,subtitle,remarks,poster_url,year,area,language,
		actors,director,score,type_name,class_name,duration,blurb,content,total_episodes,update_time,episodes_json,scraped_at
		FROM short_dramas ORDER BY scraped_at DESC,id DESC LIMIT ? OFFSET ?`, pageSize, offset)
	if err != nil {
		return nil, fmt.Errorf("list short dramas: %w", err)
	}
	defer rows.Close()
	result := make([]DramaRecord, 0, pageSize)
	for rows.Next() {
		record, err := scanDrama(rows)
		if err != nil {
			return nil, fmt.Errorf("scan short drama: %w", err)
		}
		result = append(result, record)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate short dramas: %w", err)
	}
	return result, nil
}

func (r *Repository) ByID(ctx context.Context, id uint64) (DramaRecord, error) {
	row := r.db.QueryRowContext(ctx, `SELECT id,source_id,source_name,external_id,name,subtitle,remarks,poster_url,year,area,language,
		actors,director,score,type_name,class_name,duration,blurb,content,total_episodes,update_time,episodes_json,scraped_at
		FROM short_dramas WHERE id=?`, id)
	record, err := scanDrama(row)
	if errors.Is(err, sql.ErrNoRows) {
		return DramaRecord{}, ErrNotFound
	}
	if err != nil {
		return DramaRecord{}, fmt.Errorf("read short drama: %w", err)
	}
	return record, nil
}

type scanner interface{ Scan(...any) error }

func scanDrama(s scanner) (DramaRecord, error) {
	var record DramaRecord
	var episodesJSON []byte
	err := s.Scan(&record.ID, &record.SourceID, &record.SourceName, &record.ExternalID, &record.Name, &record.Subtitle,
		&record.Remarks, &record.PosterURL, &record.Year, &record.Area, &record.Language, &record.Actors, &record.Director,
		&record.Score, &record.Type, &record.Class, &record.Duration, &record.Blurb, &record.Content, &record.TotalEpisodes,
		&record.UpdateTime, &episodesJSON, &record.ScrapedAt)
	if err != nil {
		return DramaRecord{}, err
	}
	if len(episodesJSON) == 0 {
		episodesJSON = []byte("[]")
	}
	if err := json.Unmarshal(episodesJSON, &record.Episodes); err != nil {
		return DramaRecord{}, fmt.Errorf("decode episodes: %w", err)
	}
	if record.Episodes == nil {
		record.Episodes = []Episode{}
	}
	return record, nil
}

func normalizePage(page, pageSize int) (int, int) {
	if page < 1 {
		page = 1
	}
	if pageSize < 1 {
		pageSize = 20
	}
	if pageSize > 100 {
		pageSize = 100
	}
	return page, pageSize
}
