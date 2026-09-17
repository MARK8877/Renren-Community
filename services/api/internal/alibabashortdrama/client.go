package alibabashortdrama

import (
	"context"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strconv"
	"strings"
	"time"

	"creatorhub/api/internal/shortdrama"
)

const (
	endpoint  = "https://eco.taobao.com/router/rest"
	method    = "alibaba.shuqi.content.backend.drama.searchorexport"
	pageLimit = 100
)

type Client struct {
	httpClient *http.Client
	appKey     string
	appSecret  string
	query      string
	pageSize   int
	endpoint   string
}

func NewClient(httpClient *http.Client, appKey, appSecret, query string, pageSize int) *Client {
	if httpClient == nil {
		httpClient = &http.Client{}
	}
	if pageSize < 1 || pageSize > pageLimit {
		pageSize = 20
	}
	return &Client{
		httpClient: httpClient,
		appKey:     strings.TrimSpace(appKey),
		appSecret:  strings.TrimSpace(appSecret),
		query:      strings.TrimSpace(query),
		pageSize:   pageSize,
		endpoint:   endpoint,
	}
}

func (c *Client) Fetch(ctx context.Context, limit int) ([]shortdrama.Drama, error) {
	if c.appKey == "" || c.appSecret == "" {
		return nil, fmt.Errorf("ALIBABA_APP_KEY and ALIBABA_APP_SECRET are required")
	}
	if limit < 1 || limit > pageLimit {
		return nil, fmt.Errorf("limit must be between 1 and %d", pageLimit)
	}
	pageSize := c.pageSize
	if pageSize > limit {
		pageSize = limit
	}
	params := map[string]string{
		"method":       method,
		"app_key":      c.appKey,
		"format":       "json",
		"sign_method":  "hmac",
		"timestamp":    time.Now().In(time.FixedZone("GMT+8", 8*60*60)).Format("2006-01-02 15:04:05"),
		"v":            "2.0",
		"operate_type": "1",
		"top_class":    "1314",
		"page":         "1",
		"page_size":    strconv.Itoa(pageSize),
	}
	if c.query != "" {
		params["drama_name"] = c.query
	}
	signature, err := sign(params, c.appSecret, params["sign_method"])
	if err != nil {
		return nil, err
	}
	params["sign"] = signature
	body, err := c.post(ctx, params)
	if err != nil {
		return nil, err
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

func (c *Client) post(ctx context.Context, params map[string]string) ([]byte, error) {
	values := url.Values{}
	for key, value := range params {
		values.Set(key, value)
	}
	request, err := http.NewRequestWithContext(ctx, http.MethodPost, c.endpoint, strings.NewReader(values.Encode()))
	if err != nil {
		return nil, err
	}
	request.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	request.Header.Set("User-Agent", "CreatorHubAlibabaShortDramaCollector/1.0")
	response, err := c.httpClient.Do(request)
	if err != nil {
		return nil, fmt.Errorf("request Alibaba API: %w", err)
	}
	defer response.Body.Close()
	body, err := io.ReadAll(response.Body)
	if err != nil {
		return nil, fmt.Errorf("read Alibaba API response: %w", err)
	}
	if response.StatusCode < 200 || response.StatusCode >= 300 {
		return nil, fmt.Errorf("Alibaba API HTTP %d", response.StatusCode)
	}
	return body, nil
}
