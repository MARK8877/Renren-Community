package isteroshortdrama

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strings"

	"creatorhub/api/internal/shortdrama"
)

const (
	endpoint  = "https://api.istero.com/resource/v1/short/play"
	pageLimit = 100
)

type Client struct {
	httpClient    *http.Client
	authorization string
	token         string
	query         string
	endpoint      string
}

func NewClient(httpClient *http.Client, authorization, token, query string) *Client {
	if httpClient == nil {
		httpClient = &http.Client{}
	}
	authorization = strings.TrimSpace(authorization)
	if authorization != "" && !strings.HasPrefix(strings.ToLower(authorization), "bearer ") {
		authorization = "Bearer " + authorization
	}
	return &Client{
		httpClient:    httpClient,
		authorization: authorization,
		token:         strings.TrimSpace(token),
		query:         strings.TrimSpace(query),
		endpoint:      endpoint,
	}
}

func (c *Client) Fetch(ctx context.Context, limit int) ([]shortdrama.Drama, error) {
	if c.authorization == "" && c.token == "" {
		return nil, fmt.Errorf("ISTERO_AUTHORIZATION or ISTERO_TOKEN is required")
	}
	if c.query == "" {
		return nil, fmt.Errorf("ISTERO_QUERY is required")
	}
	if limit < 1 || limit > pageLimit {
		return nil, fmt.Errorf("limit must be between 1 and %d", pageLimit)
	}
	form := url.Values{"text": {c.query}}
	if c.token != "" {
		form.Set("token", c.token)
	}
	request, err := http.NewRequestWithContext(ctx, http.MethodPost, c.endpoint, strings.NewReader(form.Encode()))
	if err != nil {
		return nil, err
	}
	request.Header.Set("Content-Type", "application/x-www-form-urlencoded;charset=UTF-8")
	request.Header.Set("User-Agent", "CreatorHubISTEROShortDramaCollector/1.0")
	if c.authorization != "" {
		request.Header.Set("Authorization", c.authorization)
	}
	response, err := c.httpClient.Do(request)
	if err != nil {
		return nil, fmt.Errorf("request ISTERO API: %w", err)
	}
	defer response.Body.Close()
	body, err := io.ReadAll(response.Body)
	if err != nil {
		return nil, fmt.Errorf("read ISTERO API response: %w", err)
	}
	if response.StatusCode < 200 || response.StatusCode >= 300 {
		var apiError struct {
			Message string `json:"message"`
		}
		if json.Unmarshal(body, &apiError) == nil && apiError.Message != "" {
			return nil, fmt.Errorf("ISTERO API HTTP %d: %s", response.StatusCode, apiError.Message)
		}
		return nil, fmt.Errorf("ISTERO API HTTP %d", response.StatusCode)
	}
	dramas, err := ParseResponse(body)
	if err != nil {
		return nil, err
	}
	if len(dramas) > limit {
		dramas = dramas[:limit]
	}
	return dramas, nil
}
