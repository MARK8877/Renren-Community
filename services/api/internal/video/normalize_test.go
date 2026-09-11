package video

import (
	"testing"
	"time"
)

func TestNormalizeMapsPlatformFieldsAndKeepsLowLikes(t *testing.T) {
	record, ok := Normalize("youtube", map[string]any{
		"videoId":     "yt-123",
		"title":       "A popular video",
		"url":         "https://youtube.com/watch?v=yt-123",
		"likes":       float64(1_250_000),
		"comments":    float64(4200),
		"publishedAt": "2026-09-01T12:30:00Z",
	})
	if !ok {
		t.Fatal("expected a valid video")
	}
	if record.ExternalID != "yt-123" || record.LikeCount != 1_250_000 || record.CommentCount != 4200 {
		t.Fatalf("unexpected normalized record: %+v", record)
	}
	if record.PublishedAt == nil || !record.PublishedAt.Equal(time.Date(2026, 9, 1, 12, 30, 0, 0, time.UTC)) {
		t.Fatalf("unexpected published time: %v", record.PublishedAt)
	}

	below, ok := Normalize("x", map[string]any{
		"id":        "x-1",
		"text":      "not popular enough",
		"url":       "https://x.com/example/status/x-1",
		"likeCount": float64(99),
	})
	if !ok || below.LikeCount != 99 {
		t.Fatalf("expected valid record below threshold: %+v, %v", below, ok)
	}
	if got := Filter([]Video{record, below}, 100); len(got) != 2 || got[0].ExternalID != "yt-123" || got[1].ExternalID != "x-1" {
		t.Fatalf("unexpected filtered records: %+v", got)
	}
}

func TestFilterKeepsExactly100Likes(t *testing.T) {
	items := []Video{
		{Platform: "youtube", ExternalID: "exact", LikeCount: 100},
		{Platform: "youtube", ExternalID: "above", LikeCount: 101},
	}
	got := Filter(items, 100)
	if len(got) != 2 || got[0].ExternalID != "exact" || got[1].ExternalID != "above" {
		t.Fatalf("expected both videos regardless of likes: %+v", got)
	}
}

func TestNormalizeTikTokUsesCreateTimeAndShareCount(t *testing.T) {
	record, ok := Normalize("douyin", map[string]any{
		"id":           "dy-9",
		"desc":         "Douyin video",
		"webVideoUrl":  "https://www.douyin.com/video/dy-9",
		"diggCount":    float64(2_000_000),
		"commentCount": 1200,
		"shareCount":   800,
		"createTime":   float64(1_756_700_000),
	})
	if !ok {
		t.Fatal("expected a valid Douyin record")
	}
	if record.Platform != "douyin" || record.Title != "Douyin video" || record.ShareCount != 800 {
		t.Fatalf("unexpected Douyin record: %+v", record)
	}
	if record.PublishedAt == nil {
		t.Fatal("expected createTime to be converted")
	}
}
