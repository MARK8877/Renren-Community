package main

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"creatorhub/api/internal/auth"
	"creatorhub/api/internal/homefeed"
)

type fakeHomePosts struct{ posts []homefeed.Post }

func (f fakeHomePosts) List(context.Context, int, int) ([]homefeed.Post, error) {
	return f.posts, nil
}

func TestListHomePostsReturnsImportedPosts(t *testing.T) {
	tokens := auth.NewTokenManager([]byte("12345678901234567890123456789012"), time.Hour)
	api := &server{
		tokens: tokens,
		homePosts: fakeHomePosts{posts: []homefeed.Post{{
			ID: 1, Source: "productschool", Author: "Product School", Role: "Artificial Intelligence",
			Content: "Agentic Architecture", Tags: []string{"#Artificial Intelligence"},
			URL: "https://productschool.com/blog/artificial-intelligence/agentic-architecture",
		}}},
	}
	mux := http.NewServeMux()
	mux.HandleFunc("GET /api/v1/home/posts", api.requireAuth(api.listHomePosts))
	token, _, err := tokens.Create(1, "user")
	if err != nil {
		t.Fatal(err)
	}

	recorder := httptest.NewRecorder()
	request := httptest.NewRequest(http.MethodGet, "/api/v1/home/posts?page=1&pageSize=10", nil)
	request.Header.Set("Authorization", "Bearer "+token)
	mux.ServeHTTP(recorder, request)
	if recorder.Code != http.StatusOK {
		t.Fatalf("status = %d, body = %s", recorder.Code, recorder.Body.String())
	}
	var result struct {
		Data []homefeed.Post `json:"data"`
	}
	if err := json.Unmarshal(recorder.Body.Bytes(), &result); err != nil {
		t.Fatal(err)
	}
	if len(result.Data) != 1 || result.Data[0].Content != "Agentic Architecture" {
		t.Fatalf("data = %#v", result.Data)
	}
}
