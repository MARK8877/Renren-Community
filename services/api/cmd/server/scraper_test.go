package main

import (
	"context"
	"errors"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"creatorhub/api/internal/auth"
	"creatorhub/api/internal/scraper"
)

type fakeScraperController struct {
	job        scraper.Job
	snapshot   scraper.StatusSnapshot
	triggerErr error
	triggered  int
}

func (f *fakeScraperController) Trigger(_ context.Context, trigger scraper.TriggerType) (scraper.Job, error) {
	f.triggered++
	if f.triggerErr != nil {
		return scraper.Job{}, f.triggerErr
	}
	f.job.TriggerType = trigger
	return f.job, nil
}

func (f *fakeScraperController) Status(_ context.Context) (scraper.StatusSnapshot, error) {
	return f.snapshot, nil
}

type fakeSchedulerView struct{ next time.Time }

func (f fakeSchedulerView) NextRunAt() time.Time { return f.next }

func scraperTestServer(controller scraperController) (*server, *auth.TokenManager) {
	tokens := auth.NewTokenManager([]byte("12345678901234567890123456789012"), time.Hour)
	return &server{tokens: tokens, scraper: controller, scraperScheduler: fakeSchedulerView{next: time.Now().Add(time.Hour)}}, tokens
}

func scraperRequest(t *testing.T, handler http.Handler, method, path, token string) *httptest.ResponseRecorder {
	t.Helper()
	req := httptest.NewRequest(method, path, nil)
	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}
	recorder := httptest.NewRecorder()
	handler.ServeHTTP(recorder, req)
	return recorder
}

func TestRunScraperRequiresAdmin(t *testing.T) {
	controller := &fakeScraperController{job: scraper.Job{ID: 42}}
	api, tokens := scraperTestServer(controller)
	mux := http.NewServeMux()
	mux.HandleFunc("POST /api/v1/admin/scraper/run", api.requireAdmin(api.runScraper))

	adminToken, _, err := tokens.Create(1, "admin")
	if err != nil {
		t.Fatal(err)
	}
	userToken, _, err := tokens.Create(2, "user")
	if err != nil {
		t.Fatal(err)
	}
	if got := scraperRequest(t, mux, http.MethodPost, "/api/v1/admin/scraper/run", "").Code; got != http.StatusUnauthorized {
		t.Fatalf("anonymous status = %d, want 401", got)
	}
	if got := scraperRequest(t, mux, http.MethodPost, "/api/v1/admin/scraper/run", userToken).Code; got != http.StatusForbidden {
		t.Fatalf("user status = %d, want 403", got)
	}
	recorder := scraperRequest(t, mux, http.MethodPost, "/api/v1/admin/scraper/run", adminToken)
	if recorder.Code != http.StatusAccepted || !strings.Contains(recorder.Body.String(), `"jobId":42`) {
		t.Fatalf("admin response = %d %s", recorder.Code, recorder.Body.String())
	}
	if controller.triggered != 1 {
		t.Fatalf("triggered = %d, want 1", controller.triggered)
	}
}

func TestRunScraperReturnsConflictWhenBusy(t *testing.T) {
	controller := &fakeScraperController{triggerErr: scraper.ErrAlreadyRunning}
	api, tokens := scraperTestServer(controller)
	mux := http.NewServeMux()
	mux.HandleFunc("POST /api/v1/admin/scraper/run", api.requireAdmin(api.runScraper))
	adminToken, _, err := tokens.Create(1, "admin")
	if err != nil {
		t.Fatal(err)
	}
	if got := scraperRequest(t, mux, http.MethodPost, "/api/v1/admin/scraper/run", adminToken).Code; got != http.StatusConflict {
		t.Fatalf("busy status = %d, want 409", got)
	}
}

func TestScraperStatusReturnsLatestJob(t *testing.T) {
	next := time.Now().Add(time.Hour)
	controller := &fakeScraperController{
		snapshot: scraper.StatusSnapshot{Running: true, Latest: &scraper.Job{ID: 9, Status: scraper.StatusRunning}},
	}
	api, tokens := scraperTestServer(controller)
	api.scraperScheduler = fakeSchedulerView{next: next}
	mux := http.NewServeMux()
	mux.HandleFunc("GET /api/v1/admin/scraper/status", api.requireAdmin(api.scraperStatus))
	adminToken, _, err := tokens.Create(1, "admin")
	if err != nil {
		t.Fatal(err)
	}
	recorder := scraperRequest(t, mux, http.MethodGet, "/api/v1/admin/scraper/status", adminToken)
	if recorder.Code != http.StatusOK || !strings.Contains(recorder.Body.String(), `"running":true`) || !strings.Contains(recorder.Body.String(), `"id":9`) {
		t.Fatalf("status response = %d %s", recorder.Code, recorder.Body.String())
	}
}

func TestRunScraperReturnsInternalError(t *testing.T) {
	controller := &fakeScraperController{triggerErr: errors.New("database unavailable")}
	api, tokens := scraperTestServer(controller)
	mux := http.NewServeMux()
	mux.HandleFunc("POST /api/v1/admin/scraper/run", api.requireAdmin(api.runScraper))
	adminToken, _, err := tokens.Create(1, "admin")
	if err != nil {
		t.Fatal(err)
	}
	if got := scraperRequest(t, mux, http.MethodPost, "/api/v1/admin/scraper/run", adminToken).Code; got != http.StatusInternalServerError {
		t.Fatalf("error status = %d, want 500", got)
	}
}
