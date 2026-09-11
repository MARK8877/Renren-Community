package scraper

import (
	"context"
	"database/sql"
	"errors"
	"time"
)

type Status string

const (
	StatusRunning   Status = "running"
	StatusSucceeded Status = "succeeded"
	StatusFailed    Status = "failed"
)

type TriggerType string

const (
	TriggerScheduled TriggerType = "scheduled"
	TriggerManual    TriggerType = "manual"
)

var (
	ErrNoJob          = errors.New("scrape job not found")
	ErrAlreadyRunning = errors.New("scrape job already running")
)

type Job struct {
	ID           uint64      `json:"id"`
	Status       Status      `json:"status"`
	TriggerType  TriggerType `json:"triggerType"`
	StartedAt    time.Time   `json:"startedAt"`
	FinishedAt   *time.Time  `json:"finishedAt,omitempty"`
	ErrorMessage string      `json:"errorMessage,omitempty"`
	CreatedAt    time.Time   `json:"createdAt"`
	UpdatedAt    time.Time   `json:"updatedAt"`
}

type JobStore interface {
	Create(ctx context.Context, trigger TriggerType) (Job, error)
	Complete(ctx context.Context, id uint64, status Status, message string) error
	Latest(ctx context.Context) (Job, error)
	MarkRunningFailed(ctx context.Context, message string) error
}

type Repository struct {
	db *sql.DB
}

func NewRepository(db *sql.DB) *Repository {
	return &Repository{db: db}
}
