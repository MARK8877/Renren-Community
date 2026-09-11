package video

import (
	"encoding/json"
	"strconv"
	"strings"
	"time"
)

type Video struct {
	ID           uint64     `json:"id,omitempty"`
	Platform     string     `json:"platform"`
	ExternalID   string     `json:"externalId"`
	Title        string     `json:"title"`
	PlayURL      string     `json:"playUrl"`
	LikeCount    uint64     `json:"likeCount"`
	CommentCount uint64     `json:"commentCount"`
	ShareCount   uint64     `json:"shareCount"`
	PublishedAt  *time.Time `json:"publishedAt,omitempty"`
	ScrapedAt    time.Time  `json:"scrapedAt"`
}

func Normalize(platform string, raw map[string]any) (Video, bool) {
	platform = strings.ToLower(strings.TrimSpace(platform))
	if platform == "tiktok" {
		platform = "douyin"
	}
	item := Video{
		Platform:     platform,
		ExternalID:   firstString(raw, "externalId", "videoId", "tweetId", "id", "awemeId"),
		Title:        firstString(raw, "title", "desc", "text", "caption"),
		PlayURL:      firstString(raw, "playUrl", "videoUrl", "webVideoUrl", "url", "postUrl"),
		LikeCount:    firstNumber(raw, "likeCount", "likesCount", "likes", "diggCount", "favoriteCount"),
		CommentCount: firstNumber(raw, "commentCount", "commentsCount", "comments", "replyCount"),
		ShareCount:   firstNumber(raw, "shareCount", "sharesCount", "shares", "repostCount", "retweetCount"),
		ScrapedAt:    time.Now().UTC(),
	}
	item.PublishedAt = firstTime(raw, "publishedAt", "publishDate", "createdAt", "createTime", "timestamp")
	return item, item.Platform != "" && item.ExternalID != "" && item.Title != "" && item.PlayURL != ""
}

func Filter(items []Video, _ uint64) []Video {
	result := make([]Video, 0, len(items))
	seen := make(map[string]struct{}, len(items))
	for _, item := range items {
		if item.ExternalID == "" {
			continue
		}
		key := item.Platform + ":" + item.ExternalID
		if _, exists := seen[key]; exists {
			continue
		}
		seen[key] = struct{}{}
		result = append(result, item)
	}
	return result
}

func firstString(raw map[string]any, keys ...string) string {
	for _, key := range keys {
		if value, ok := raw[key].(string); ok && strings.TrimSpace(value) != "" {
			return strings.TrimSpace(value)
		}
	}
	return ""
}

func firstNumber(raw map[string]any, keys ...string) uint64 {
	for _, key := range keys {
		if value, ok := raw[key]; ok {
			if parsed := number(value); parsed > 0 {
				return parsed
			}
		}
	}
	return 0
}

func number(value any) uint64 {
	switch value := value.(type) {
	case uint64:
		return value
	case uint:
		return uint64(value)
	case int:
		if value > 0 {
			return uint64(value)
		}
	case int64:
		if value > 0 {
			return uint64(value)
		}
	case float64:
		if value > 0 {
			return uint64(value)
		}
	case json.Number:
		parsed, _ := strconv.ParseUint(string(value), 10, 64)
		return parsed
	case string:
		parsed, _ := strconv.ParseUint(strings.TrimSpace(value), 10, 64)
		return parsed
	}
	return 0
}

func firstTime(raw map[string]any, keys ...string) *time.Time {
	for _, key := range keys {
		value, ok := raw[key]
		if !ok {
			continue
		}
		if parsed, ok := parseTime(value); ok {
			return &parsed
		}
	}
	return nil
}

func parseTime(value any) (time.Time, bool) {
	switch value := value.(type) {
	case time.Time:
		return value, true
	case float64:
		return unixTime(value)
	case int64:
		return unixTime(float64(value))
	case json.Number:
		parsed, err := strconv.ParseFloat(string(value), 64)
		if err == nil {
			return unixTime(parsed)
		}
	case string:
		if parsed, err := time.Parse(time.RFC3339, strings.TrimSpace(value)); err == nil {
			return parsed, true
		}
		if parsed, err := strconv.ParseFloat(strings.TrimSpace(value), 64); err == nil {
			return unixTime(parsed)
		}
	}
	return time.Time{}, false
}

func unixTime(value float64) (time.Time, bool) {
	if value <= 0 {
		return time.Time{}, false
	}
	if value > 1e12 {
		value /= 1000
	}
	return time.Unix(int64(value), 0).UTC(), true
}
