// Package tiktok contains the Bright Data integration used to import public
// TikTok video metadata into the existing platform_videos table.
package tiktok

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strings"
	"time"

	"creatorhub/api/internal/video"
)

const (
	defaultScrapeEndpoint = "https://api.brightdata.com/datasets/v3/scrape"
	defaultProgressBase   = "https://api.brightdata.com/datasets/v3"
	defaultSourceURL      = "https://www.tiktok.com/explore"
	maxResponseBytes      = 16 << 20
)

// Fetcher calls Bright Data's pre-built TikTok scraper. datasetID must be the
// TikTok dataset selected in the Bright Data Scraper Library; it is not safe
// to guess this account-specific identifier.
type Fetcher struct {
	client    *http.Client
	apiKey    string
	datasetID string
	sourceURL string
	endpoint  string
	progress  string
	pollEvery time.Duration
	pollLimit time.Duration
}

func NewFetcher(client *http.Client, apiKey, datasetID, sourceURL string) *Fetcher {
	if client == nil {
		client = &http.Client{Timeout: 45 * time.Second}
	}
	if strings.TrimSpace(sourceURL) == "" {
		sourceURL = defaultSourceURL
	}
	return &Fetcher{
		client: client, apiKey: strings.TrimSpace(apiKey), datasetID: strings.TrimSpace(datasetID),
		sourceURL: strings.TrimSpace(sourceURL), endpoint: defaultScrapeEndpoint,
		progress: defaultProgressBase, pollEvery: 2 * time.Second, pollLimit: 2 * time.Minute,
	}
}

func (f *Fetcher) Fetch(ctx context.Context, limit int) ([]video.Video, error) {
	if f == nil || strings.TrimSpace(f.apiKey) == "" {
		return nil, errors.New("BRIGHTDATA_API_KEY is required")
	}
	if strings.TrimSpace(f.datasetID) == "" {
		return nil, errors.New("BRIGHTDATA_TIKTOK_DATASET_ID is required")
	}
	if limit <= 0 {
		limit = 20
	}
	if limit > 100 {
		limit = 100
	}

	payload, err := json.Marshal(map[string]any{"input": []map[string]string{{"url": f.sourceURL}}})
	if err != nil {
		return nil, fmt.Errorf("encode Bright Data request: %w", err)
	}
	requestURL, err := withQuery(f.endpoint, map[string]string{
		"dataset_id": f.datasetID, "format": "json", "include_errors": "true",
	})
	if err != nil {
		return nil, err
	}
	request, err := http.NewRequestWithContext(ctx, http.MethodPost, requestURL, bytes.NewReader(payload))
	if err != nil {
		return nil, err
	}
	request.Header.Set("Authorization", "Bearer "+f.apiKey)
	request.Header.Set("Content-Type", "application/json")
	response, err := f.client.Do(request)
	if err != nil {
		return nil, fmt.Errorf("Bright Data TikTok request: %w", err)
	}
	body, err := readBody(response)
	if err != nil {
		return nil, err
	}
	if response.StatusCode == http.StatusAccepted {
		var accepted struct {
			SnapshotID string `json:"snapshot_id"`
		}
		if err := json.Unmarshal(body, &accepted); err != nil || accepted.SnapshotID == "" {
			return nil, errors.New("Bright Data returned 202 without snapshot_id")
		}
		body, err = f.waitForSnapshot(ctx, accepted.SnapshotID)
		if err != nil {
			return nil, err
		}
	} else if response.StatusCode < 200 || response.StatusCode >= 300 {
		return nil, fmt.Errorf("Bright Data TikTok request failed (%d): %s", response.StatusCode, compact(body, 500))
	}
	rawItems, err := unwrapResults(body)
	if err != nil {
		return nil, err
	}
	items := make([]video.Video, 0, len(rawItems))
	for _, raw := range rawItems {
		if item, ok := video.Normalize("tiktok", raw); ok {
			items = append(items, item)
		}
	}
	items = video.Filter(items, 0)
	if len(items) > limit {
		items = items[:limit]
	}
	return items, nil
}

func (f *Fetcher) waitForSnapshot(ctx context.Context, snapshotID string) ([]byte, error) {
	deadline := time.Now().Add(f.pollLimit)
	for {
		if time.Now().After(deadline) {
			return nil, fmt.Errorf("Bright Data snapshot %s timed out", snapshotID)
		}
		statusURL := strings.TrimSuffix(f.progress, "/") + "/progress/" + url.PathEscape(snapshotID)
		request, err := http.NewRequestWithContext(ctx, http.MethodGet, statusURL, nil)
		if err != nil {
			return nil, err
		}
		request.Header.Set("Authorization", "Bearer "+f.apiKey)
		response, err := f.client.Do(request)
		if err != nil {
			return nil, fmt.Errorf("poll Bright Data snapshot: %w", err)
		}
		body, readErr := readBody(response)
		if readErr != nil {
			return nil, readErr
		}
		if response.StatusCode < 200 || response.StatusCode >= 300 {
			return nil, fmt.Errorf("Bright Data snapshot status failed (%d): %s", response.StatusCode, compact(body, 500))
		}
		var status struct {
			Status string `json:"status"`
		}
		if err := json.Unmarshal(body, &status); err != nil {
			return nil, fmt.Errorf("decode Bright Data snapshot status: %w", err)
		}
		switch strings.ToLower(status.Status) {
		case "ready", "completed", "success", "succeeded":
			resultURL := strings.TrimSuffix(f.progress, "/") + "/snapshot/" + url.PathEscape(snapshotID)
			resultRequest, err := http.NewRequestWithContext(ctx, http.MethodGet, resultURL, nil)
			if err != nil {
				return nil, err
			}
			resultRequest.Header.Set("Authorization", "Bearer "+f.apiKey)
			resultResponse, err := f.client.Do(resultRequest)
			if err != nil {
				return nil, fmt.Errorf("read Bright Data snapshot: %w", err)
			}
			return readBody(resultResponse)
		case "failed", "error":
			return nil, fmt.Errorf("Bright Data TikTok snapshot failed: %s", compact(body, 500))
		}
		timer := time.NewTimer(f.pollEvery)
		select {
		case <-ctx.Done():
			timer.Stop()
			return nil, ctx.Err()
		case <-timer.C:
		}
	}
}

func unwrapResults(payload []byte) ([]map[string]any, error) {
	var array []map[string]any
	if err := json.Unmarshal(payload, &array); err == nil {
		return array, nil
	}
	var envelope map[string]json.RawMessage
	if err := json.Unmarshal(payload, &envelope); err != nil {
		return nil, fmt.Errorf("decode Bright Data TikTok results: %w", err)
	}
	for _, key := range []string{"data", "results", "items"} {
		if nested, ok := envelope[key]; ok {
			return unwrapResults(nested)
		}
	}
	var item map[string]any
	if err := json.Unmarshal(payload, &item); err == nil && item != nil {
		return []map[string]any{item}, nil
	}
	return nil, errors.New("Bright Data TikTok response did not contain results")
}

func withQuery(raw string, values map[string]string) (string, error) {
	parsed, err := url.Parse(raw)
	if err != nil {
		return "", fmt.Errorf("parse Bright Data endpoint: %w", err)
	}
	query := parsed.Query()
	for key, value := range values {
		query.Set(key, value)
	}
	parsed.RawQuery = query.Encode()
	return parsed.String(), nil
}

func readBody(response *http.Response) ([]byte, error) {
	defer response.Body.Close()
	body, err := io.ReadAll(io.LimitReader(response.Body, maxResponseBytes))
	if err != nil {
		return nil, err
	}
	return body, nil
}

func compact(body []byte, limit int) string {
	value := strings.TrimSpace(string(body))
	if len(value) <= limit {
		return value
	}
	return value[:limit] + "..."
}
