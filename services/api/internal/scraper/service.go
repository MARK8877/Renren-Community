package scraper

import (
	"context"
	"errors"
	"sync"
	"time"
)

type StatusSnapshot struct {
	Running bool `json:"running"`
	Latest  *Job `json:"latest,omitempty"`
}

type Service struct {
	store   JobStore
	command Command
	timeout time.Duration

	mu      sync.Mutex
	running bool
}

func NewService(store JobStore, command Command, timeout time.Duration) *Service {
	return &Service{store: store, command: command, timeout: timeout}
}

func (s *Service) Trigger(ctx context.Context, trigger TriggerType) (Job, error) {
	s.mu.Lock()
	if s.running {
		s.mu.Unlock()
		return Job{}, ErrAlreadyRunning
	}
	job, err := s.store.Create(ctx, trigger)
	if err != nil {
		s.mu.Unlock()
		return Job{}, err
	}
	s.running = true
	s.mu.Unlock()
	go s.execute(job.ID)
	return job, nil
}

func (s *Service) Status(ctx context.Context) (StatusSnapshot, error) {
	s.mu.Lock()
	running := s.running
	s.mu.Unlock()

	job, err := s.store.Latest(ctx)
	if errors.Is(err, ErrNoJob) {
		return StatusSnapshot{Running: running}, nil
	}
	if err != nil {
		return StatusSnapshot{}, err
	}
	return StatusSnapshot{Running: running, Latest: &job}, nil
}

func (s *Service) MarkStale(ctx context.Context) error {
	return s.store.MarkRunningFailed(ctx, "server restarted")
}

func (s *Service) execute(jobID uint64) {
	defer func() {
		s.mu.Lock()
		s.running = false
		s.mu.Unlock()
	}()

	ctx := context.Background()
	if s.timeout > 0 {
		var cancel context.CancelFunc
		ctx, cancel = context.WithTimeout(ctx, s.timeout)
		defer cancel()
	}
	_, err := s.command.Run(ctx)
	status := StatusSucceeded
	message := ""
	if err != nil {
		status = StatusFailed
		message = err.Error()
	}
	_ = s.store.Complete(context.Background(), jobID, status, message)
}
