package main

import (
	"net/http/httptest"
	"testing"
)

func TestParseVideoQueryDefaultsToSafePageSize(t *testing.T) {
	r := httptest.NewRequest("GET", "/api/v1/videos", nil)
	platform, page, pageSize := parseVideoQuery(r)
	if platform != "" || page != 1 || pageSize != 20 {
		t.Fatalf("unexpected defaults: %q %d %d", platform, page, pageSize)
	}
}

func TestParseVideoQueryClampsPageSize(t *testing.T) {
	r := httptest.NewRequest("GET", "/api/v1/videos?platform=x&minLikes=2000000&page=0&pageSize=500", nil)
	platform, page, pageSize := parseVideoQuery(r)
	if platform != "x" || page != 1 || pageSize != 100 {
		t.Fatalf("unexpected query: %q %d %d", platform, page, pageSize)
	}
}

func TestParseVideoQueryMapsTikTokToStoredPlatform(t *testing.T) {
	r := httptest.NewRequest("GET", "/api/v1/videos?platform=tiktok", nil)
	platform, _, _ := parseVideoQuery(r)
	if platform != "douyin" {
		t.Fatalf("platform = %q, want douyin", platform)
	}
}
