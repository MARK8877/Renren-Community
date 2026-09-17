package aa1shortdrama

import (
	"bytes"
	"encoding/json"
	"fmt"
	"regexp"
	"strconv"

	"creatorhub/api/internal/shortdrama"
)

const (
	sourceID   = 100001
	sourceName = "AA1 免费短剧 API"
)

var episodeCountPattern = regexp.MustCompile(`([0-9]+)\s*集`)

type apiResponse struct {
	Code    int             `json:"code"`
	Message string          `json:"message"`
	Data    json.RawMessage `json:"data"`
}

type pageData struct {
	Rows []dramaRow `json:"rows"`
}

type dramaRow struct {
	ID       json.RawMessage `json:"id"`
	Name     string          `json:"name"`
	CreateAt json.RawMessage `json:"createAt"`
	UpdateAt json.RawMessage `json:"updateAt"`
	Link     string          `json:"link"`
}

func ParseResponse(body []byte) ([]shortdrama.Drama, error) {
	trimmed := bytes.TrimSpace(body)
	if len(trimmed) > 0 && trimmed[0] == '<' {
		return nil, fmt.Errorf("AA1 API returned HTML instead of JSON; the upstream endpoint may be unavailable")
	}
	var response apiResponse
	if err := json.Unmarshal(trimmed, &response); err != nil {
		return nil, fmt.Errorf("decode AA1 API response: %w", err)
	}
	if response.Code != 0 {
		return nil, fmt.Errorf("AA1 API error %d: %s", response.Code, response.Message)
	}
	if len(response.Data) == 0 || string(response.Data) == "null" {
		return nil, fmt.Errorf("AA1 API response has no data")
	}
	var page pageData
	if err := json.Unmarshal(response.Data, &page); err != nil {
		return nil, fmt.Errorf("decode AA1 drama page: %w", err)
	}
	result := make([]shortdrama.Drama, 0, len(page.Rows))
	for _, row := range page.Rows {
		externalID := rawString(row.ID)
		if externalID == "" || row.Name == "" {
			continue
		}
		episodes := make([]shortdrama.Episode, 0, 1)
		if row.Link != "" {
			episodes = append(episodes, shortdrama.Episode{Title: "全集资源", URL: row.Link})
		}
		result = append(result, shortdrama.Drama{
			SourceID:      sourceID,
			SourceName:    sourceName,
			ExternalID:    externalID,
			Name:          row.Name,
			Type:          "短剧",
			Blurb:         "来自 AA1 免费短剧 API",
			Content:       row.Name,
			TotalEpisodes: episodeCount(row.Name),
			UpdateTime:    rawString(row.UpdateAt),
			Episodes:      episodes,
		})
	}
	return result, nil
}

func episodeCount(name string) int {
	match := episodeCountPattern.FindStringSubmatch(name)
	if len(match) != 2 {
		return 0
	}
	value, _ := strconv.Atoi(match[1])
	return value
}

func rawString(raw json.RawMessage) string {
	if len(raw) == 0 || string(raw) == "null" {
		return ""
	}
	var text string
	if json.Unmarshal(raw, &text) == nil {
		return text
	}
	var number json.Number
	if json.Unmarshal(raw, &number) == nil {
		return number.String()
	}
	return ""
}
