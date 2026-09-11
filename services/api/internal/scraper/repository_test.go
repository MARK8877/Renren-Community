package scraper

import (
	"context"
	"database/sql"
	"errors"
	"os"
	"testing"

	_ "github.com/go-sql-driver/mysql"
)

func TestRepository(t *testing.T) {
	dsn := os.Getenv("MYSQL_TEST_DSN")
	if dsn == "" {
		t.Skip("MYSQL_TEST_DSN is not set")
	}
	db, err := sql.Open("mysql", dsn)
	if err != nil {
		t.Fatal(err)
	}
	defer db.Close()
	if err := db.PingContext(context.Background()); err != nil {
		t.Fatal(err)
	}
	migration, err := os.ReadFile("../../migrations/000007_create_video_scrape_jobs.sql")
	if err != nil {
		t.Fatal(err)
	}
	if _, err := db.ExecContext(context.Background(), string(migration)); err != nil {
		t.Fatal(err)
	}

	store := NewRepository(db)
	ctx := context.Background()
	job, err := store.Create(ctx, TriggerManual)
	if err != nil {
		t.Fatal(err)
	}
	if job.Status != StatusRunning || job.TriggerType != TriggerManual {
		t.Fatalf("unexpected created job: %+v", job)
	}
	if err := store.Complete(ctx, job.ID, StatusSucceeded, ""); err != nil {
		t.Fatal(err)
	}
	latest, err := store.Latest(ctx)
	if err != nil {
		t.Fatal(err)
	}
	if latest.ID != job.ID || latest.Status != StatusSucceeded || latest.FinishedAt == nil {
		t.Fatalf("unexpected completed job: %+v", latest)
	}
	if err := store.Complete(ctx, 999999999, StatusSucceeded, ""); !errors.Is(err, ErrNoJob) {
		t.Fatalf("Complete missing job error = %v, want ErrNoJob", err)
	}
	if _, err := db.ExecContext(ctx, "DELETE FROM video_scrape_jobs WHERE id=?", job.ID); err != nil {
		t.Fatal(err)
	}
}
