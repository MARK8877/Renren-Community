package main

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"net/url"
	"strconv"
	"strings"
	"time"

	"creatorhub/api/internal/auth"
	"creatorhub/api/internal/quarkshortdrama"
	"creatorhub/api/internal/shortdrama"
)

const localDramaSourceID = 8999

type localDramaPlayback struct {
	client  *http.Client
	baseURL string
}

func newLocalDramaPlayback(baseURL string) *localDramaPlayback {
	baseURL = strings.TrimRight(strings.TrimSpace(baseURL), "/")
	if baseURL == "" {
		baseURL = "http://[::1]:8999"
	}
	return &localDramaPlayback{client: &http.Client{Timeout: 20 * time.Second}, baseURL: baseURL}
}

func (c *localDramaPlayback) Preview(ctx context.Context, dramaID string, episode int) (quarkshortdrama.Preview, error) {
	openBody, _ := json.Marshal(map[string]any{"dramaId": dramaID, "resume": false})
	var opened struct {
		Session string `json:"session"`
	}
	if err := c.postJSON(ctx, "/api/ui/playback/open", openBody, &opened); err != nil {
		return quarkshortdrama.Preview{}, fmt.Errorf("open local drama: %w", err)
	}
	if opened.Session == "" {
		return quarkshortdrama.Preview{}, fmt.Errorf("local drama session is empty")
	}
	base, err := url.Parse(c.baseURL)
	if err != nil {
		return quarkshortdrama.Preview{}, fmt.Errorf("parse local drama base URL: %w", err)
	}
	streamURL := base.ResolveReference(&url.URL{Path: "/api/ui/playback/stream"})
	query := streamURL.Query()
	query.Set("session", opened.Session)
	query.Set("episode", strconv.Itoa(episode))
	query.Set("start", "0")
	query.Set("quality", "0")
	query.Set("version", "1")
	streamURL.RawQuery = query.Encode()
	return quarkshortdrama.Preview{URL: streamURL.String()}, nil
}

func (c *localDramaPlayback) Release(ctx context.Context, session string) error {
	session = strings.TrimSpace(session)
	if session == "" {
		return fmt.Errorf("local drama session is empty")
	}
	body, _ := json.Marshal(map[string]any{"session": session, "action": "close"})
	var result struct {
		OK bool `json:"ok"`
	}
	if err := c.postJSON(ctx, "/api/ui/playback/control", body, &result); err != nil {
		return fmt.Errorf("release local drama: %w", err)
	}
	return nil
}

func (c *localDramaPlayback) postJSON(ctx context.Context, path string, body []byte, target any) error {
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, c.baseURL+path, strings.NewReader(string(body)))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/json")
	res, err := c.client.Do(req)
	if err != nil {
		return err
	}
	defer res.Body.Close()
	if res.StatusCode < http.StatusOK || res.StatusCode >= http.StatusMultipleChoices {
		return fmt.Errorf("HTTP %s", res.Status)
	}
	return json.NewDecoder(res.Body).Decode(target)
}

type shortDramaStore interface {
	List(context.Context, int, int) ([]shortdrama.DramaRecord, error)
	ByID(context.Context, uint64) (shortdrama.DramaRecord, error)
}

type shortDramaPreviewer interface {
	Preview(context.Context, quarkshortdrama.Episode) (quarkshortdrama.Preview, error)
}

type shortDramaListItem struct {
	ID            uint64                  `json:"id"`
	SourceID      int                     `json:"sourceId"`
	SourceName    string                  `json:"sourceName"`
	ExternalID    string                  `json:"externalId"`
	Name          string                  `json:"name"`
	UpdateTime    string                  `json:"updateTime"`
	TotalEpisodes int                     `json:"totalEpisodes"`
	Episodes      []shortDramaEpisodeData `json:"episodes"`
}

type shortDramaEpisodeData struct {
	Episode  int    `json:"episode"`
	Title    string `json:"title"`
	PwdID    string `json:"pwdId,omitempty"`
	FID      string `json:"fid,omitempty"`
	FIDToken string `json:"fidToken,omitempty"`
	Size     int64  `json:"size,omitempty"`
	Duration int64  `json:"duration,omitempty"`
	URL      string `json:"url,omitempty"`
	M3U8URL  string `json:"m3u8url,omitempty"`
}

func (s *server) listShortDramas(w http.ResponseWriter, r *http.Request, _ auth.Claims) {
	if s.shortDramas == nil {
		writeJSON(w, 500, response{Code: 10500, Message: "短剧服务未初始化"})
		return
	}
	page, pageSize := positiveQueryInt(r, "page", 1), positiveQueryInt(r, "pageSize", 20)
	items, err := s.shortDramas.List(r.Context(), page, pageSize)
	if err != nil {
		writeJSON(w, 500, response{Code: 10500, Message: "读取短剧失败"})
		return
	}
	data := make([]shortDramaListItem, 0, len(items))
	for _, item := range items {
		data = append(data, shortDramaListItemFromRecord(item))
	}
	writeJSON(w, 200, response{Code: 0, Message: "ok", Data: data})
}

func (s *server) shortDramaPlayURL(w http.ResponseWriter, r *http.Request, _ auth.Claims) {
	if s.shortDramas == nil || (s.quark == nil && s.localDrama == nil) {
		writeJSON(w, 500, response{Code: 10500, Message: "短剧服务未初始化"})
		return
	}
	id, err := strconv.ParseUint(r.PathValue("id"), 10, 64)
	if err != nil || id == 0 {
		writeJSON(w, 400, response{Code: 10400, Message: "短剧 ID 不正确"})
		return
	}
	index, err := strconv.Atoi(r.PathValue("index"))
	if err != nil || index < 1 {
		writeJSON(w, 400, response{Code: 10400, Message: "剧集序号不正确"})
		return
	}
	record, err := s.shortDramas.ByID(r.Context(), id)
	if errors.Is(err, shortdrama.ErrNotFound) {
		writeJSON(w, 404, response{Code: 10404, Message: "短剧不存在"})
		return
	}
	if err != nil {
		writeJSON(w, 500, response{Code: 10500, Message: "读取短剧失败"})
		return
	}
	if index > len(record.Episodes) {
		writeJSON(w, 404, response{Code: 10404, Message: "剧集不存在"})
		return
	}
	ep := record.Episodes[index-1]
	var preview quarkshortdrama.Preview
	if record.SourceID == localDramaSourceID && s.localDrama != nil {
		preview, err = s.localDrama.Preview(r.Context(), record.ExternalID, ep.Episode)
	} else {
		preview, err = s.quark.Preview(r.Context(), quarkshortdrama.Episode{Episode: ep.Episode, Title: ep.Title, PwdID: ep.PwdID, FID: ep.FID, FIDToken: ep.FIDToken})
	}
	if err != nil {
		writeJSON(w, 502, response{Code: 10502, Message: "刷新播放地址失败"})
		return
	}
	writeJSON(w, 200, response{Code: 0, Message: "ok", Data: map[string]any{"url": preview.URL, "duration": preview.Duration}})
}

func (s *server) shortDramaRelease(w http.ResponseWriter, r *http.Request, _ auth.Claims) {
	if s.shortDramas == nil || s.localDrama == nil {
		writeJSON(w, 200, response{Code: 0, Message: "ok"})
		return
	}
	id, err := strconv.ParseUint(r.PathValue("id"), 10, 64)
	if err != nil || id == 0 {
		writeJSON(w, 400, response{Code: 10400, Message: "短剧 ID 不正确"})
		return
	}
	record, err := s.shortDramas.ByID(r.Context(), id)
	if errors.Is(err, shortdrama.ErrNotFound) {
		writeJSON(w, 404, response{Code: 10404, Message: "短剧不存在"})
		return
	}
	if err != nil {
		writeJSON(w, 500, response{Code: 10500, Message: "读取短剧失败"})
		return
	}
	if record.SourceID != localDramaSourceID {
		writeJSON(w, 200, response{Code: 0, Message: "ok"})
		return
	}
	var input struct {
		Session string `json:"session"`
	}
	if !decodeJSON(w, r, &input) {
		return
	}
	if err := s.localDrama.Release(r.Context(), input.Session); err != nil {
		writeJSON(w, 502, response{Code: 10502, Message: "关闭播放会话失败"})
		return
	}
	writeJSON(w, 200, response{Code: 0, Message: "ok"})
}

func shortDramaListItemFromRecord(record shortdrama.DramaRecord) shortDramaListItem {
	item := shortDramaListItem{ID: record.ID, SourceID: record.SourceID, SourceName: record.SourceName, ExternalID: record.ExternalID, Name: record.Name, UpdateTime: record.UpdateTime, TotalEpisodes: record.TotalEpisodes, Episodes: make([]shortDramaEpisodeData, 0, len(record.Episodes))}
	for _, ep := range record.Episodes {
		item.Episodes = append(item.Episodes, shortDramaEpisodeData{Episode: ep.Episode, Title: ep.Title, PwdID: ep.PwdID, FID: ep.FID, FIDToken: ep.FIDToken, Size: ep.Size, Duration: ep.Duration, URL: ep.URL, M3U8URL: ep.M3U8URL})
	}
	return item
}

func positiveQueryInt(r *http.Request, key string, fallback int) int {
	value, err := strconv.Atoi(strings.TrimSpace(r.URL.Query().Get(key)))
	if err != nil || value < 1 {
		return fallback
	}
	return value
}
