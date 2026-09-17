package shortdrama

import (
	"bytes"
	"encoding/json"
	"fmt"
	"strconv"
)

type apiEnvelope struct {
	Code int             `json:"code"`
	Msg  string          `json:"msg"`
	Data json.RawMessage `json:"data"`
}

type sourceInfo struct {
	ID   int    `json:"id"`
	Name string `json:"name"`
}

type listPayload struct {
	Source sourceInfo   `json:"source"`
	List   []listRecord `json:"list"`
}

type listRecord struct {
	N             int             `json:"n"`
	ID            json.RawMessage `json:"id"`
	Name          string          `json:"name"`
	Subtitle      string          `json:"subtitle"`
	Remarks       string          `json:"remarks"`
	Pic           string          `json:"pic"`
	Year          string          `json:"year"`
	Area          string          `json:"area"`
	Language      string          `json:"language"`
	Actor         string          `json:"actor"`
	Director      string          `json:"director"`
	Score         string          `json:"score"`
	Type          string          `json:"type"`
	Class         string          `json:"class"`
	Duration      string          `json:"duration"`
	Blurb         string          `json:"blurb"`
	Content       string          `json:"content"`
	TotalEpisodes int             `json:"total_episodes"`
	UpdateTime    string          `json:"update_time"`
}

type detailPayload struct {
	Source        sourceInfo      `json:"source"`
	ID            json.RawMessage `json:"id"`
	Name          string          `json:"name"`
	Subtitle      string          `json:"subtitle"`
	Pic           string          `json:"pic"`
	Area          string          `json:"area"`
	Year          string          `json:"year"`
	Language      string          `json:"language"`
	Remarks       string          `json:"remarks"`
	Actors        string          `json:"actors"`
	Director      string          `json:"director"`
	Score         string          `json:"douban_score"`
	Type          string          `json:"type"`
	Class         string          `json:"class"`
	Duration      string          `json:"duration"`
	UpdateTime    string          `json:"update_time"`
	Blurb         string          `json:"blurb"`
	Intro         string          `json:"intro"`
	Content       string          `json:"content"`
	TotalEpisodes int             `json:"total_episodes"`
	Episodes      []Episode       `json:"episodes"`
}

func ParseSearchResponse(body []byte) (SearchResult, error) {
	envelope, err := parseEnvelope(body)
	if err != nil {
		return SearchResult{}, err
	}
	var payload listPayload
	if err := json.Unmarshal(envelope.Data, &payload); err != nil {
		return SearchResult{}, fmt.Errorf("decode search data: %w", err)
	}
	result := SearchResult{
		SourceID: payload.Source.ID, SourceName: payload.Source.Name,
		Items: make([]SearchItem, 0, len(payload.List)),
	}
	for _, item := range payload.List {
		result.Items = append(result.Items, SearchItem{
			N: item.N, ExternalID: rawString(item.ID), Name: item.Name, Subtitle: item.Subtitle,
			Remarks: item.Remarks, PosterURL: item.Pic, Year: item.Year, Area: item.Area,
			Language: item.Language, Actors: item.Actor, Director: item.Director,
			Score: item.Score, Type: item.Type, Class: item.Class, Duration: item.Duration,
			Blurb: item.Blurb, Content: item.Content, TotalEpisodes: item.TotalEpisodes,
			UpdateTime: item.UpdateTime,
		})
	}
	return result, nil
}

func ParseDetailResponse(body []byte) (Drama, error) {
	envelope, err := parseEnvelope(body)
	if err != nil {
		return Drama{}, err
	}
	var payload detailPayload
	if err := json.Unmarshal(envelope.Data, &payload); err != nil {
		return Drama{}, fmt.Errorf("decode detail data: %w", err)
	}
	episodes := payload.Episodes
	if episodes == nil {
		episodes = []Episode{}
	}
	return Drama{
		SourceID: payload.Source.ID, SourceName: payload.Source.Name,
		ExternalID: rawString(payload.ID), Name: payload.Name, Subtitle: payload.Subtitle,
		PosterURL: payload.Pic, Year: payload.Year, Area: payload.Area,
		Language: payload.Language, Remarks: payload.Remarks, Actors: payload.Actors,
		Director: payload.Director, Score: payload.Score, Type: payload.Type,
		Class: payload.Class, Duration: payload.Duration, UpdateTime: payload.UpdateTime,
		Blurb: payload.Blurb, Content: payload.Content, TotalEpisodes: payload.TotalEpisodes,
		Episodes: episodes,
	}, nil
}

func parseEnvelope(body []byte) (apiEnvelope, error) {
	var envelope apiEnvelope
	if err := json.Unmarshal(bytes.TrimSpace(body), &envelope); err != nil {
		return apiEnvelope{}, fmt.Errorf("decode API response: %w", err)
	}
	if envelope.Code != 200 {
		return apiEnvelope{}, fmt.Errorf("yaohud API error %d: %s", envelope.Code, envelope.Msg)
	}
	return envelope, nil
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
