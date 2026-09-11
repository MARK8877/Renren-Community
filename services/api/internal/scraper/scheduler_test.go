package scraper

import (
	"context"
	"testing"
	"time"
)

func TestSchedulerTriggersAtConfiguredInterval(t *testing.T) {
	store := &fakeJobStore{}
	command := &fakeCommand{started: make(chan struct{}, 1), release: make(chan struct{})}
	service := NewService(store, command, time.Second)
	scheduler := NewScheduler(service, 10*time.Millisecond)
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go scheduler.Run(ctx)
	select {
	case <-command.started:
	case <-time.After(time.Second):
		t.Fatal("scheduler did not trigger the command")
	}
	if scheduler.NextRunAt().Before(time.Now()) {
		t.Fatalf("next run is in the past: %s", scheduler.NextRunAt())
	}
	close(command.release)
	waitForStatus(t, store, StatusSucceeded)
	cancel()
}
