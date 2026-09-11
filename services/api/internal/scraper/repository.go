package scraper

import (
	"context"
	"database/sql"
	"fmt"
)

func (r *Repository) Create(ctx context.Context, trigger TriggerType) (Job, error) {
	if trigger != TriggerScheduled && trigger != TriggerManual {
		return Job{}, fmt.Errorf("invalid scrape trigger type %q", trigger)
	}
	result, err := r.db.ExecContext(ctx, `
		INSERT INTO video_scrape_jobs (status, trigger_type, started_at)
		VALUES ('running', ?, NOW(3))`, trigger)
	if err != nil {
		return Job{}, err
	}
	id, err := result.LastInsertId()
	if err != nil {
		return Job{}, err
	}
	return r.byID(ctx, uint64(id))
}

func (r *Repository) Complete(ctx context.Context, id uint64, status Status, message string) error {
	if status != StatusSucceeded && status != StatusFailed {
		return fmt.Errorf("invalid completed scrape status %q", status)
	}
	result, err := r.db.ExecContext(ctx, `
		UPDATE video_scrape_jobs
		SET status=?, finished_at=NOW(3), error_message=NULLIF(?, '')
		WHERE id=?`, status, message, id)
	if err != nil {
		return err
	}
	affected, err := result.RowsAffected()
	if err != nil {
		return err
	}
	if affected == 0 {
		return ErrNoJob
	}
	return nil
}

func (r *Repository) Latest(ctx context.Context) (Job, error) {
	return r.scan(ctx, r.db.QueryRowContext(ctx, `
		SELECT id,status,trigger_type,started_at,finished_at,COALESCE(error_message,''),created_at,updated_at
		FROM video_scrape_jobs ORDER BY id DESC LIMIT 1`))
}

func (r *Repository) MarkRunningFailed(ctx context.Context, message string) error {
	_, err := r.db.ExecContext(ctx, `
		UPDATE video_scrape_jobs
		SET status='failed', finished_at=NOW(3), error_message=NULLIF(?, '')
		WHERE status='running'`, message)
	return err
}

func (r *Repository) byID(ctx context.Context, id uint64) (Job, error) {
	return r.scan(ctx, r.db.QueryRowContext(ctx, `
		SELECT id,status,trigger_type,started_at,finished_at,COALESCE(error_message,''),created_at,updated_at
		FROM video_scrape_jobs WHERE id=?`, id))
}

func (r *Repository) scan(ctx context.Context, row *sql.Row) (Job, error) {
	var job Job
	var finishedAt sql.NullTime
	if err := row.Scan(
		&job.ID,
		&job.Status,
		&job.TriggerType,
		&job.StartedAt,
		&finishedAt,
		&job.ErrorMessage,
		&job.CreatedAt,
		&job.UpdatedAt,
	); err != nil {
		if err == sql.ErrNoRows {
			return Job{}, ErrNoJob
		}
		return Job{}, err
	}
	if finishedAt.Valid {
		value := finishedAt.Time
		job.FinishedAt = &value
	}
	return job, nil
}
