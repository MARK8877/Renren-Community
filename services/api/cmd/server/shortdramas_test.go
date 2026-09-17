package main

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"creatorhub/api/internal/auth"
	"creatorhub/api/internal/quarkshortdrama"
	"creatorhub/api/internal/shortdrama"
)

type fakeShortDramaStore struct{ record shortdrama.DramaRecord }

func (f fakeShortDramaStore) List(context.Context, int, int) ([]shortdrama.DramaRecord, error) {
	return []shortdrama.DramaRecord{f.record}, nil
}
func (f fakeShortDramaStore) ByID(context.Context, uint64) (shortdrama.DramaRecord, error) {
	return f.record, nil
}

type fakeShortDramaPreviewer struct{}

func (fakeShortDramaPreviewer) Preview(context.Context, quarkshortdrama.Episode) (quarkshortdrama.Preview, error) {
	return quarkshortdrama.Preview{URL: "https://cdn.example/e1.m3u8", Duration: 90}, nil
}

func TestShortDramaListRequiresAuth(t *testing.T) {
	api := &server{tokens: auth.NewTokenManager([]byte("test-secret-with-at-least-32-characters"), time.Hour)}
	mux := http.NewServeMux()
	mux.HandleFunc("GET /api/v1/short-dramas", api.requireAuth(api.listShortDramas))
	req := httptest.NewRequest(http.MethodGet, "/api/v1/short-dramas", nil)
	res := httptest.NewRecorder()
	mux.ServeHTTP(res, req)
	if res.Code != http.StatusUnauthorized {
		t.Fatalf("status = %d, want 401", res.Code)
	}
}

func TestPositiveQueryInt(t *testing.T) {
	req := httptest.NewRequest(http.MethodGet, "/?page=3&pageSize=0", nil)
	if got := positiveQueryInt(req, "page", 1); got != 3 {
		t.Fatalf("page = %d, want 3", got)
	}
	if got := positiveQueryInt(req, "pageSize", 20); got != 20 {
		t.Fatalf("pageSize = %d, want fallback 20", got)
	}
}

func TestShortDramaListReturnsPersistedRecord(t *testing.T) {
	api := &server{shortDramas: fakeShortDramaStore{record: shortdrama.DramaRecord{ID: 7, Drama: shortdrama.Drama{Name: "测试短剧", TotalEpisodes: 1, Episodes: []shortdrama.Episode{{Episode: 1, Title: "第1集.mp4"}}}}}, tokens: auth.NewTokenManager([]byte("test-secret-with-at-least-32-characters"), time.Hour)}
	token, _, err := api.tokens.Create(1, "user")
	if err != nil {
		t.Fatal(err)
	}
	req := httptest.NewRequest(http.MethodGet, "/api/v1/short-dramas", nil)
	req.Header.Set("Authorization", "Bearer "+token)
	res := httptest.NewRecorder()
	api.requireAuth(api.listShortDramas).ServeHTTP(res, req)
	if res.Code != http.StatusOK {
		t.Fatalf("status = %d, want 200", res.Code)
	}
	var body response
	if err := json.NewDecoder(res.Body).Decode(&body); err != nil {
		t.Fatal(err)
	}
	if body.Code != 0 {
		t.Fatalf("response code = %d", body.Code)
	}
}

func TestShortDramaPlayURLDoesNotExposeToken(t *testing.T) {
	api := &server{shortDramas: fakeShortDramaStore{record: shortdrama.DramaRecord{ID: 7, Drama: shortdrama.Drama{Episodes: []shortdrama.Episode{{Episode: 1, PwdID: "pwd", FID: "fid", FIDToken: "share-token"}}}}}, quark: fakeShortDramaPreviewer{}, tokens: auth.NewTokenManager([]byte("test-secret-with-at-least-32-characters"), time.Hour)}
	token, _, _ := api.tokens.Create(1, "user")
	req := httptest.NewRequest(http.MethodGet, "/api/v1/short-dramas/7/episodes/1/play-url", nil)
	req.SetPathValue("id", "7")
	req.SetPathValue("index", "1")
	req.Header.Set("Authorization", "Bearer "+token)
	res := httptest.NewRecorder()
	api.requireAuth(api.shortDramaPlayURL).ServeHTTP(res, req)
	if res.Code != http.StatusOK {
		t.Fatalf("status = %d, want 200", res.Code)
	}
	if strings.Contains(res.Body.String(), "stoken") {
		t.Fatal("play response exposes stoken")
	}
}
