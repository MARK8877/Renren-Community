package shortdrama

import (
	"context"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strconv"
	"strings"
)

const endpoint = "https://api.yaohud.cn/api/v5/yingshi"

type Client struct {
	httpClient *http.Client
	apiKey     string
	query      string
	source     int
	endpoint   string
}

func NewClient(httpClient *http.Client, apiKey, query string, source int) *Client {
	if httpClient == nil {
		httpClient = &http.Client{}
	}
	return &Client{
		httpClient: httpClient,
		apiKey:     strings.TrimSpace(apiKey),
		query:      strings.TrimSpace(query),
		source:     source,
		endpoint:   endpoint,
	}
}

func (c *Client) Fetch(ctx context.Context, limit int) ([]Drama, error) {
	if c.apiKey == "" {
		return nil, fmt.Errorf("YAOHUD_API_KEY is required")
	}
	if c.query == "" {
		return nil, fmt.Errorf("YAOHUD_QUERY is required")
	}
	if c.source < 1 || c.source > 4 {
		return nil, fmt.Errorf("YAOHUD_SOURCE must be between 1 and 4")
	}
	if limit < 1 || limit > 100 {
		return nil, fmt.Errorf("limit must be between 1 and 100")
	}

	searchBody, err := c.get(ctx, 0)
	if err != nil {
		return nil, err
	}
	search, err := ParseSearchResponse(searchBody)
	if err != nil {
		return nil, err
	}
	if len(search.Items) > limit {
		search.Items = search.Items[:limit]
	}
	result := make([]Drama, 0, len(search.Items))
	for _, item := range search.Items {
		if item.N < 1 {
			continue
		}
		detailBody, err := c.get(ctx, item.N)
		if err != nil {
			return nil, fmt.Errorf("fetch detail %s: %w", item.ExternalID, err)
		}
		drama, err := ParseDetailResponse(detailBody)
		if err != nil {
			return nil, fmt.Errorf("parse detail %s: %w", item.ExternalID, err)
		}
		if drama.ExternalID == "" {
			drama.ExternalID = item.ExternalID
		}
		if drama.SourceID == 0 {
			drama.SourceID = search.SourceID
		}
		if drama.SourceName == "" {
			drama.SourceName = search.SourceName
		}
		result = append(result, drama)
	}
	return result, nil
}

func (c *Client) get(ctx context.Context, n int) ([]byte, error) {
	params := url.Values{
		"key":    {c.apiKey},
		"msg":    {c.query},
		"source": {strconv.Itoa(c.source)},
	}
	if n > 0 {
		params.Set("n", strconv.Itoa(n))
	}
	request, err := http.NewRequestWithContext(ctx, http.MethodGet, c.endpoint+"?"+params.Encode(), nil)
	if err != nil {
		return nil, err
	}
	request.Header.Set("User-Agent", "CreatorHubShortDramaCollector/1.0")
	response, err := c.httpClient.Do(request)
	if err != nil {
		return nil, fmt.Errorf("request yaohud API: %w", err)
	}
	defer response.Body.Close()
	body, err := io.ReadAll(response.Body)
	if err != nil {
		return nil, fmt.Errorf("read yaohud API: %w", err)
	}
	if response.StatusCode < 200 || response.StatusCode >= 300 {
		return nil, fmt.Errorf("yaohud API HTTP %d", response.StatusCode)
	}
	return body, nil
}
