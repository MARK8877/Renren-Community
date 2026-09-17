package alibabashortdrama

import (
	"bytes"
	"encoding/json"
	"fmt"
	"strconv"

	"creatorhub/api/internal/shortdrama"
)

const (
	sourceID   = 71096
	sourceName = "书旗短剧"
)

type responseEnvelope struct {
	State   int             `json:"state"`
	Message string          `json:"message"`
	Data    json.RawMessage `json:"data"`
}

type pageData struct {
	List json.RawMessage `json:"list"`
}

type dramaRecord struct {
	ID            json.RawMessage `json:"drama_id"`
	Name          string          `json:"drama_name"`
	Category      string          `json:"category_name"`
	Tags          string          `json:"tag_names"`
	Introduction  string          `json:"introduction"`
	CoverURL      string          `json:"cover_url"`
	TotalEpisodes int             `json:"total_episodes"`
}

func ParseResponse(body []byte) ([]shortdrama.Drama, error) {
	envelope, err := decodeEnvelope(body)
	if err != nil {
		return nil, err
	}
	var page pageData
	if err := json.Unmarshal(envelope.Data, &page); err != nil {
		return nil, fmt.Errorf("decode drama page: %w", err)
	}
	records, err := decodeRecords(page.List)
	if err != nil {
		return nil, err
	}
	result := make([]shortdrama.Drama, 0, len(records))
	for _, record := range records {
		externalID := rawString(record.ID)
		if externalID == "" || record.Name == "" {
			continue
		}
		result = append(result, shortdrama.Drama{
			SourceID:      sourceID,
			SourceName:    sourceName,
			ExternalID:    externalID,
			Name:          record.Name,
			Remarks:       record.Tags,
			PosterURL:     record.CoverURL,
			Type:          "短剧",
			Class:         record.Category,
			Blurb:         record.Introduction,
			Content:       record.Introduction,
			TotalEpisodes: record.TotalEpisodes,
			Episodes:      []shortdrama.Episode{},
		})
	}
	return result, nil
}

func decodeEnvelope(body []byte) (responseEnvelope, error) {
	var root map[string]json.RawMessage
	if err := json.Unmarshal(bytes.TrimSpace(body), &root); err != nil {
		return responseEnvelope{}, fmt.Errorf("decode Alibaba API response: %w", err)
	}
	var envelope responseEnvelope
	if raw, ok := root["alibaba_shuqi_content_backend_drama_searchorexport_response"]; ok {
		if err := json.Unmarshal(raw, &envelope); err != nil {
			return responseEnvelope{}, fmt.Errorf("decode Alibaba response envelope: %w", err)
		}
	} else {
		if err := json.Unmarshal(bytes.TrimSpace(body), &envelope); err != nil {
			return responseEnvelope{}, fmt.Errorf("decode Alibaba response envelope: %w", err)
		}
	}
	if envelope.State != 200 {
		return responseEnvelope{}, fmt.Errorf("Alibaba API error %d: %s", envelope.State, envelope.Message)
	}
	if len(envelope.Data) == 0 || string(envelope.Data) == "null" {
		return responseEnvelope{}, fmt.Errorf("Alibaba API response has no data")
	}
	return envelope, nil
}

func decodeRecords(raw json.RawMessage) ([]dramaRecord, error) {
	var wrapper struct {
		Records []dramaRecord `json:"drama_list_biz_response"`
	}
	if err := json.Unmarshal(raw, &wrapper); err == nil && wrapper.Records != nil {
		return wrapper.Records, nil
	}
	var records []dramaRecord
	if err := json.Unmarshal(raw, &records); err != nil {
		return nil, fmt.Errorf("decode drama list: %w", err)
	}
	return records, nil
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
	return strconv.FormatInt(0, 10)
}
