package scraper

import (
	"context"
	"errors"
	"sync"
	"testing"
	"time"
)

type fakeJobStore struct {
	mu       sync.Mutex
	nextID   uint64
	jobs     []Job
	staleErr error
}

func (s *fakeJobStore) Create(_ context.Context, trigger TriggerType) (Job, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.nextID++
	now := time.Now()
	job := Job{ID: s.nextID, Status: StatusRunning, TriggerType: trigger, StartedAt: now, CreatedAt: now, UpdatedAt: now}
	s.jobs = append(s.jobs, job)
	return job, nil
}

func (s *fakeJobStore) Complete(_ context.Context, id uint64, status Status, message string) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	for index := range s.jobs {
		if s.jobs[index].ID == id {
			now := time.Now()
			s.jobs[index].Status = status
			s.jobs[index].ErrorMessage = message
			s.jobs[index].FinishedAt = &now
			s.jobs[index].UpdatedAt = now
			return nil
		}
	}
	return ErrNoJob
}

func (s *fakeJobStore) Latest(_ context.Context) (Job, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if len(s.jobs) == 0 {
		return Job{}, ErrNoJob
	}
	return s.jobs[len(s.jobs)-1], nil
}

func (s *fakeJobStore) MarkRunningFailed(_ context.Context, message string) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.staleErr != nil {
		return s.staleErr
	}
	for index := range s.jobs {
		if s.jobs[index].Status == StatusRunning {
			s.jobs[index].Status = StatusFailed
			s.jobs[index].ErrorMessage = message
		}
	}
	return nil
}

type fakeCommand struct {
	started chan struct{}
	release chan struct{}
	result  RunResult
	err     error
}

func (c *fakeCommand) Run(ctx context.Context) (RunResult, error) {
	if c.started != nil {
		select {
		case c.started <- struct{}{}:
		default:
		}
	}
	if c.release != nil {
		select {
		case <-c.release:
		case <-ctx.Done():
			return RunResult{}, ctx.Err()
		}
	}
	return c.result, c.err
}

func waitForStatus(t *testing.T, store *fakeJobStore, status Status) Job {
	t.Helper()
	deadline := time.Now().Add(time.Second)
	for time.Now().Before(deadline) {
		job, err := store.Latest(context.Background())
		if err == nil && job.Status == status {
			return job
		}
		time.Sleep(time.Millisecond)
	}
	t.Fatalf("job did not reach status %q", status)
	return Job{}
}

func TestServiceCompletesSuccessfulJob(t *testing.T) {
	store := &fakeJobStore{}
	service := NewService(store, &fakeCommand{result: RunResult{Discovered: 50, Processed: 50}}, time.Second)
	job, err := service.Trigger(context.Background(), TriggerManual)
	if err != nil {
		t.Fatal(err)
	}
	if job.ID != 1 {
		t.Fatalf("job ID = %d, want 1", job.ID)
	}
	completed := waitForStatus(t, store, StatusSucceeded)
	if completed.ErrorMessage != "" || completed.FinishedAt == nil {
		t.Fatalf("unexpected completed job: %+v", completed)
	}
}

func TestServiceRecordsFailedJob(t *testing.T) {
	store := &fakeJobStore{}
	service := NewService(store, &fakeCommand{err: errors.New("pexels unavailable")}, time.Second)
	if _, err := service.Trigger(context.Background(), TriggerManual); err != nil {
		t.Fatal(err)
	}
	failed := waitForStatus(t, store, StatusFailed)
	if failed.ErrorMessage != "pexels unavailable" {
		t.Fatalf("error message = %q", failed.ErrorMessage)
	}
}

func TestServiceRejectsConcurrentTrigger(t *testing.T) {
	store := &fakeJobStore{}
	command := &fakeCommand{started: make(chan struct{}, 1), release: make(chan struct{})}
	service := NewService(store, command, time.Second)
	if _, err := service.Trigger(context.Background(), TriggerManual); err != nil {
		t.Fatal(err)
	}
	select {
	case <-command.started:
	case <-time.After(time.Second):
		t.Fatal("first command did not start")
	}
	if _, err := service.Trigger(context.Background(), TriggerScheduled); !errors.Is(err, ErrAlreadyRunning) {
		t.Fatalf("second trigger error = %v, want ErrAlreadyRunning", err)
	}
	close(command.release)
	waitForStatus(t, store, StatusSucceeded)
}

func TestServiceMarksStaleJobs(t *testing.T) {
	store := &fakeJobStore{}
	job, err := store.Create(context.Background(), TriggerScheduled)
	if err != nil {
		t.Fatal(err)
	}
	service := NewService(store, &fakeCommand{}, time.Second)
	if err := service.MarkStale(context.Background()); err != nil {
		t.Fatal(err)
	}
	latest, err := store.Latest(context.Background())
	if err != nil || latest.ID != job.ID || latest.Status != StatusFailed {
		t.Fatalf("unexpected stale job: %+v, err=%v", latest, err)
	}
}
