package quarkshortdrama

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"regexp"
	"sort"
	"strconv"
	"strings"
	"time"
)

const defaultAPIHost = "https://drive-m.quark.cn"

var episodeNumber = regexp.MustCompile(`第\s*(\d+)\s*集`)

type Client struct {
	httpClient *http.Client
	apiHost    string
}

func NewClient(httpClient *http.Client, apiHost string) *Client {
	if httpClient == nil {
		httpClient = &http.Client{Timeout: 20 * time.Second}
	}
	apiHost = strings.TrimRight(strings.TrimSpace(apiHost), "/")
	if apiHost == "" {
		apiHost = defaultAPIHost
	}
	return &Client{httpClient: httpClient, apiHost: apiHost}
}

type tokenResponse struct {
	Code    int    `json:"code"`
	Message string `json:"message"`
	Data    struct {
		Stoken   string `json:"stoken"`
		Title    string `json:"title"`
		FirstFID string `json:"first_fid"`
	} `json:"data"`
}
type detailResponse struct {
	Code    int    `json:"code"`
	Message string `json:"message"`
	Data    struct {
		List    []detailItem `json:"list"`
		HasMore bool         `json:"has_more"`
	} `json:"data"`
}
type detailItem struct {
	FID           string          `json:"fid"`
	FIDToken      string          `json:"fid_token"`
	ShareFIDToken string          `json:"share_fid_token"`
	FileName      string          `json:"file_name"`
	FormatType    string          `json:"format_type"`
	FileType      json.RawMessage `json:"file_type"`
	MimeType      string          `json:"mime_type"`
	IsDir         bool            `json:"is_dir"`
	Size          int64           `json:"size"`
	Duration      int64           `json:"duration"`
}
type previewResponse struct {
	Code    int    `json:"code"`
	Message string `json:"message"`
	Data    struct {
		Duration int64 `json:"duration"`
		PlayInfo struct {
			URL string `json:"url"`
		} `json:"play_info"`
	} `json:"data"`
}

func (c *Client) Collect(ctx context.Context, shareURL string, limit int) (Drama, error) {
	if limit < 1 {
		return Drama{}, fmt.Errorf("limit must be at least 1")
	}
	pwdID, rootFID, err := ParseShareURL(shareURL)
	if err != nil {
		return Drama{}, err
	}
	token, err := c.token(ctx, pwdID)
	if err != nil {
		return Drama{}, err
	}
	if rootFID == "" {
		rootFID = token.Data.FirstFID
	}
	if rootFID == "" {
		return Drama{}, fmt.Errorf("Quark share has no root directory")
	}
	items, err := c.walk(ctx, pwdID, token.Data.Stoken, rootFID, limit)
	if err != nil {
		return Drama{}, err
	}
	sort.SliceStable(items, func(i, j int) bool {
		ni, nj := episodeNo(items[i].FileName), episodeNo(items[j].FileName)
		if ni > 0 && nj > 0 && ni != nj {
			return ni < nj
		}
		if ni > 0 && nj == 0 {
			return true
		}
		if ni == 0 && nj > 0 {
			return false
		}
		return items[i].FileName < items[j].FileName
	})
	drama := Drama{ExternalID: pwdID + ":" + rootFID, Name: token.Data.Title, UpdateTime: time.Now().UTC().Format(time.RFC3339), Episodes: make([]Episode, 0, len(items))}
	if drama.Name == "" {
		drama.Name = "夸克公开分享短剧"
	}
	for i, item := range items {
		fidToken := item.FIDToken
		if fidToken == "" {
			fidToken = item.ShareFIDToken
		}
		preview, err := c.preview(ctx, pwdID, token.Data.Stoken, item.FID, fidToken)
		if err != nil {
			// ponytail: retain metadata and retry playback lazily from the API.
			preview.Duration = item.Duration
		}
		n := episodeNo(item.FileName)
		if n == 0 {
			n = i + 1
		}
		drama.Episodes = append(drama.Episodes, Episode{Episode: n, Title: item.FileName, PwdID: pwdID, FID: item.FID, FIDToken: fidToken, Size: item.Size, Duration: preview.Duration, URL: preview.URL, M3U8URL: preview.URL})
	}
	return drama, nil
}

func (c *Client) Preview(ctx context.Context, ep Episode) (Preview, error) {
	if ep.PwdID == "" || ep.FID == "" || ep.FIDToken == "" {
		return Preview{}, fmt.Errorf("episode identifiers are incomplete")
	}
	token, err := c.token(ctx, ep.PwdID)
	if err != nil {
		return Preview{}, err
	}
	return c.preview(ctx, ep.PwdID, token.Data.Stoken, ep.FID, ep.FIDToken)
}

func (c *Client) token(ctx context.Context, pwdID string) (tokenResponse, error) {
	body, err := json.Marshal(map[string]string{"pwd_id": pwdID, "passcode": ""})
	if err != nil {
		return tokenResponse{}, err
	}
	var out tokenResponse
	if err := c.doJSON(ctx, http.MethodPost, "/1/clouddrive/share/sharepage/token", "", body, &out); err != nil {
		return out, err
	}
	if out.Code != 0 && out.Code != 200 {
		return out, fmt.Errorf("Quark token API error %d: %s", out.Code, out.Message)
	}
	if out.Data.Stoken == "" {
		return out, fmt.Errorf("Quark token response missing stoken")
	}
	return out, nil
}

func (c *Client) walk(ctx context.Context, pwdID, stoken, fid string, limit int) ([]detailItem, error) {
	queue := []string{fid}
	seen := map[string]bool{}
	videos := make([]detailItem, 0, limit)
	for len(queue) > 0 && len(videos) < limit {
		current := queue[0]
		queue = queue[1:]
		if seen[current] {
			continue
		}
		seen[current] = true
		page := 1
		for {
			var out detailResponse
			query := url.Values{"pwd_id": {pwdID}, "stoken": {stoken}, "pdir_fid": {current}, "_page": {strconv.Itoa(page)}, "_size": {"100"}}
			if err := c.doJSON(ctx, http.MethodGet, "/1/clouddrive/share/sharepage/detail", query.Encode(), nil, &out); err != nil {
				return nil, err
			}
			if out.Code != 0 && out.Code != 200 {
				return nil, fmt.Errorf("Quark detail API error %d: %s", out.Code, out.Message)
			}
			for _, item := range out.Data.List {
				if isDirectory(item) {
					if item.FID != "" {
						queue = append(queue, item.FID)
					}
					continue
				}
				if strings.HasPrefix(strings.ToLower(item.FormatType), "video/") || strings.HasPrefix(strings.ToLower(item.MimeType), "video/") || strings.HasSuffix(strings.ToLower(item.FileName), ".mp4") || strings.HasSuffix(strings.ToLower(item.FileName), ".mov") || strings.HasSuffix(strings.ToLower(item.FileName), ".m3u8") {
					videos = append(videos, item)
					if len(videos) >= limit {
						break
					}
				}
			}
			if len(videos) >= limit || len(out.Data.List) == 0 || (!out.Data.HasMore && len(out.Data.List) < 100) {
				break
			}
			page++
		}
	}
	return videos, nil
}

func isDirectory(item detailItem) bool {
	if item.IsDir || strings.EqualFold(string(item.FileType), `"folder"`) {
		return true
	}
	// Quark marks folders without a MIME type; video files have a known
	// extension or video format, while images retain their image format.
	return item.FormatType == "" && item.MimeType == "" && !isVideoFilename(item.FileName)
}

func isVideoFilename(name string) bool {
	lower := strings.ToLower(name)
	for _, ext := range []string{".mp4", ".mov", ".m4v", ".mkv", ".webm", ".avi", ".m3u8"} {
		if strings.HasSuffix(lower, ext) {
			return true
		}
	}
	return false
}

func (c *Client) preview(ctx context.Context, pwdID, stoken, fid, fidToken string) (Preview, error) {
	query := url.Values{"pwd_id": {pwdID}, "stoken": {stoken}, "fid": {fid}, "fid_token": {fidToken}}
	var out previewResponse
	if err := c.doJSONWithHeader(ctx, http.MethodGet, "/1/clouddrive/share/sharepage/video_preview", query.Encode(), "x-clouddrive-st", stoken, &out); err != nil {
		return Preview{}, err
	}
	if out.Code != 0 && out.Code != 200 {
		return Preview{}, fmt.Errorf("Quark preview API error %d: %s", out.Code, out.Message)
	}
	if out.Data.PlayInfo.URL == "" {
		return Preview{}, fmt.Errorf("Quark preview response missing playback URL")
	}
	return Preview{URL: out.Data.PlayInfo.URL, Duration: out.Data.Duration}, nil
}

func (c *Client) doJSON(ctx context.Context, method, path, query string, body []byte, out any) error {
	return c.doJSONWithHeader(ctx, method, path, query, "", "", body, out)
}
func (c *Client) doJSONWithHeader(ctx context.Context, method, path, query, header, value string, args ...any) error {
	var body []byte
	var out any
	if len(args) == 1 {
		out = args[0]
	} else {
		body, _ = args[0].([]byte)
		out = args[1]
	}
	target := c.apiHost + path
	if query != "" {
		target += "?" + query
	}
	req, err := http.NewRequestWithContext(ctx, method, target, strings.NewReader(string(body)))
	if err != nil {
		return err
	}
	req.Header.Set("Accept", "application/json")
	if len(body) > 0 {
		req.Header.Set("Content-Type", "application/json")
	}
	if header != "" {
		req.Header.Set(header, value)
	}
	resp, err := c.httpClient.Do(req)
	if err != nil {
		return fmt.Errorf("request Quark API: %w", err)
	}
	defer resp.Body.Close()
	data, err := io.ReadAll(io.LimitReader(resp.Body, 4<<20))
	if err != nil {
		return err
	}
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return fmt.Errorf("Quark API HTTP %d", resp.StatusCode)
	}
	if err := json.Unmarshal(data, out); err != nil {
		return fmt.Errorf("decode Quark API response: %w", err)
	}
	return nil
}

func episodeNo(name string) int {
	m := episodeNumber.FindStringSubmatch(name)
	if len(m) != 2 {
		return 0
	}
	n, _ := strconv.Atoi(m[1])
	return n
}
