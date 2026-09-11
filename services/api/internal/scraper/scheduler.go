package scraper

import (
	"context"
	"errors"
	"log"
	"sync"
	"time"
)

const (
	DefaultInterval = 4 * time.Hour
	DefaultLimit    = 50
)

type Scheduler struct {
	service  *Service
	interval time.Duration

	mu        sync.RWMutex
	nextRunAt time.Time
}

func NewScheduler(service *Service, interval time.Duration) *Scheduler {
	if interval <= 0 {
		interval = DefaultInterval
	}
	return &Scheduler{
		service:   service,
		interval:  interval,
		nextRunAt: time.Now().Add(interval),
	}
}

func (s *Scheduler) Run(ctx context.Context) {
	ticker := time.NewTicker(s.interval)
	defer ticker.Stop()
	s.setNextRunAt(time.Now().Add(s.interval))
	for {
		select {
		case tick := <-ticker.C:
			s.setNextRunAt(tick.Add(s.interval))
			if _, err := s.service.Trigger(context.Background(), TriggerScheduled); err != nil && !errors.Is(err, ErrAlreadyRunning) {
				log.Printf("scheduled video scrape failed to start: %v", err)
			}
		case <-ctx.Done():
			return
		}
	}
}

func (s *Scheduler) NextRunAt() time.Time {
	s.mu.RLock()
	defer s.mu.RUnlock()
	return s.nextRunAt
}

func (s *Scheduler) setNextRunAt(value time.Time) {
	s.mu.Lock()
	s.nextRunAt = value
	s.mu.Unlock()
}
