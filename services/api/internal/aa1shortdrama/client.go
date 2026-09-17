package aa1shortdrama

import (
	"context"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strconv"
	"strings"

	"creatorhub/api/internal/shortdrama"
)

const (
	endpoint  = "https://api.hytys.cn/api/"
	pageLimit = 100
)

type Client struct {
	httpClient *http.Client
	query      string
	pageSize   int
	endpoint   string
}

func NewClient(httpClient *http.Client, query string, pageSize int) *Client {
	if httpClient == nil {
		httpClient = &http.Client{}
	}
	if pageSize < 1 || pageSize > pageLimit {
		pageSize = 20
	}
	return &Client{
		httpClient: httpClient,
		query:      strings.TrimSpace(query),
		pageSize:   pageSize,
		endpoint:   endpoint,
	}
}

func (c *Client) Fetch(ctx context.Context, limit int) ([]shortdrama.Drama, error) {
	if limit < 1 || limit > pageLimit {
		return nil, fmt.Errorf("limit must be between 1 and %d", pageLimit)
	}
	pageSize := c.pageSize
	if pageSize > limit {
		pageSize = limit
	}
	params := url.Values{
		"path":  {"movies"},
		"page":  {"1"},
		"limit": {strconv.Itoa(pageSize)},
	}
	if c.query != "" {
		params.Set("name", c.query)
	}
	request, err := http.NewRequestWithContext(ctx, http.MethodGet, c.endpoint+"?"+params.Encode(), nil)
	if err != nil {
		return nil, err
	}
	request.Header.Set("User-Agent", "CreatorHubAA1ShortDramaCollector/1.0")
	response, err := c.httpClient.Do(request)
	if err != nil {
		return nil, fmt.Errorf("request AA1 API: %w", err)
	}
	defer response.Body.Close()
	body, err := io.ReadAll(response.Body)
	if err != nil {
		return nil, fmt.Errorf("read AA1 API response: %w", err)
	}
	if response.StatusCode < 200 || response.StatusCode >= 300 {
		return nil, fmt.Errorf("AA1 API HTTP %d", response.StatusCode)
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
