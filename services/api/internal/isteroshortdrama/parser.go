package isteroshortdrama

import (
	"bytes"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"regexp"
	"strconv"

	"creatorhub/api/internal/shortdrama"
)

const (
	sourceID   = 100002
	sourceName = "ISTERO 全网短剧"
)

var episodeCountPattern = regexp.MustCompile(`([0-9]+)\s*集`)

type apiResponse struct {
	Code    int             `json:"code"`
	Data    json.RawMessage `json:"data"`
	Message string          `json:"message"`
}

type resource struct {
	Title string `json:"title"`
	URL   string `json:"url"`
	Time  string `json:"time"`
}

func ParseResponse(body []byte) ([]shortdrama.Drama, error) {
	trimmed := bytes.TrimSpace(body)
	if len(trimmed) > 0 && trimmed[0] == '<' {
		return nil, fmt.Errorf("ISTERO API returned HTML instead of JSON; the upstream endpoint may be unavailable")
	}
	var response apiResponse
	if err := json.Unmarshal(trimmed, &response); err != nil {
		return nil, fmt.Errorf("decode ISTERO API response: %w", err)
	}
	if response.Code != 200 {
		return nil, fmt.Errorf("ISTERO API error %d: %s", response.Code, response.Message)
	}
	if len(response.Data) == 0 || string(response.Data) == "null" {
		return nil, fmt.Errorf("ISTERO API response has no data")
	}
	var resources []resource
	if err := json.Unmarshal(response.Data, &resources); err != nil {
		return nil, fmt.Errorf("decode ISTERO short-drama data: %w", err)
	}
	result := make([]shortdrama.Drama, 0, len(resources))
	seen := make(map[string]struct{}, len(resources))
	for _, item := range resources {
		if item.Title == "" || item.URL == "" {
			continue
		}
		if _, exists := seen[item.URL]; exists {
			continue
		}
		seen[item.URL] = struct{}{}
		result = append(result, shortdrama.Drama{
			SourceID:      sourceID,
			SourceName:    sourceName,
			ExternalID:    externalID(item.URL),
			Name:          item.Title,
			Type:          "短剧",
			Blurb:         "来自 ISTERO 全网短剧",
			Content:       item.Title,
			TotalEpisodes: episodeCount(item.Title),
			UpdateTime:    item.Time,
			Episodes: []shortdrama.Episode{{
				Title: "全集资源",
				URL:   item.URL,
			}},
		})
	}
	return result, nil
}

func externalID(rawURL string) string {
	digest := sha256.Sum256([]byte(rawURL))
	return hex.EncodeToString(digest[:16])
}

func episodeCount(name string) int {
	match := episodeCountPattern.FindStringSubmatch(name)
	if len(match) != 2 {
		return 0
	}
	value, _ := strconv.Atoi(match[1])
	return value
}
