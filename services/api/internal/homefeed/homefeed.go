package homefeed

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"html"
	"io"
	"net/http"
	"regexp"
	"strings"
	"time"
)

const productSchoolBlogURL = "https://productschool.com/blog?page=2"
const indieHackersHomeURL = "https://www.indiehackers.com/"

type Post struct {
	ID          uint64     `json:"id,omitempty"`
	Source      string     `json:"source"`
	ExternalID  string     `json:"externalId"`
	Author      string     `json:"author"`
	Role        string     `json:"role"`
	Content     string     `json:"content"`
	Tags        []string   `json:"tags"`
	URL         string     `json:"url"`
	SourceOrder int        `json:"-"`
	PublishedAt *time.Time `json:"publishedAt,omitempty"`
	ScrapedAt   time.Time  `json:"scrapedAt"`
}

type ProductSchoolFetcher struct {
	client     *http.Client
	apiKey     string
	zone       string
	listingURL string
}

// IndieHackersFetcher reads the public Indie Hackers home feed. Bright Data
// Web Unlocker is used when configured; otherwise the public page is fetched
// directly so local development does not require a paid proxy.
type IndieHackersFetcher struct {
	client     *http.Client
	apiKey     string
	zone       string
	listingURL string
}

func NewIndieHackersFetcher(client *http.Client, apiKey, zone string) *IndieHackersFetcher {
	if client == nil {
		client = &http.Client{Timeout: 20 * time.Second}
	}
	return &IndieHackersFetcher{
		client: client, apiKey: strings.TrimSpace(apiKey), zone: strings.TrimSpace(zone), listingURL: indieHackersHomeURL,
	}
}

func (f *IndieHackersFetcher) Fetch(ctx context.Context) ([]Post, error) {
	body, err := f.fetchListing(ctx)
	if err != nil {
		return nil, err
	}
	posts := ParseIndieHackersListing(body)
	scrapedAt := time.Now().UTC()
	for index := range posts {
		posts[index].ScrapedAt = scrapedAt
	}
	return posts, nil
}

func (f *IndieHackersFetcher) fetchListing(ctx context.Context) ([]byte, error) {
	if f.apiKey != "" && f.zone != "" {
		payload, err := json.Marshal(map[string]string{
			"zone": f.zone, "url": f.listingURL, "format": "raw",
		})
		if err != nil {
			return nil, err
		}
		request, err := http.NewRequestWithContext(ctx, http.MethodPost, "https://api.brightdata.com/request", bytes.NewReader(payload))
		if err != nil {
			return nil, err
		}
		request.Header.Set("Authorization", "Bearer "+f.apiKey)
		request.Header.Set("Content-Type", "application/json")
		return readResponse(f.client.Do(request))
	}
	request, err := http.NewRequestWithContext(ctx, http.MethodGet, f.listingURL, nil)
	if err != nil {
		return nil, err
	}
	request.Header.Set("User-Agent", "CreatorHub/1.0 (+https://localhost)")
	return readResponse(f.client.Do(request))
}

func NewProductSchoolFetcher(client *http.Client, apiKey, zone string) *ProductSchoolFetcher {
	if client == nil {
		client = &http.Client{Timeout: 20 * time.Second}
	}
	return &ProductSchoolFetcher{
		client: client, apiKey: strings.TrimSpace(apiKey), zone: strings.TrimSpace(zone), listingURL: productSchoolBlogURL,
	}
}

func (f *ProductSchoolFetcher) Fetch(ctx context.Context) ([]Post, error) {
	body, err := f.fetchListing(ctx)
	if err != nil {
		return nil, err
	}
	posts := ParseProductSchoolListing(body)
	scrapedAt := time.Now().UTC()
	for index := range posts {
		posts[index].ScrapedAt = scrapedAt
	}
	return posts, nil
}

func (f *ProductSchoolFetcher) fetchListing(ctx context.Context) ([]byte, error) {
	if f.apiKey != "" && f.zone != "" {
		return f.fetchWithUnlocker(ctx)
	}
	request, err := http.NewRequestWithContext(ctx, http.MethodGet, f.listingURL, nil)
	if err != nil {
		return nil, err
	}
	request.Header.Set("User-Agent", "CreatorHub/1.0 (+https://localhost)")
	return readResponse(f.client.Do(request))
}

func (f *ProductSchoolFetcher) fetchWithUnlocker(ctx context.Context) ([]byte, error) {
	payload, err := json.Marshal(map[string]string{
		"zone": f.zone, "url": f.listingURL, "format": "raw",
	})
	if err != nil {
		return nil, err
	}
	request, err := http.NewRequestWithContext(ctx, http.MethodPost, "https://api.brightdata.com/request", bytes.NewReader(payload))
	if err != nil {
		return nil, err
	}
	request.Header.Set("Authorization", "Bearer "+f.apiKey)
	request.Header.Set("Content-Type", "application/json")
	return readResponse(f.client.Do(request))
}

func readResponse(response *http.Response, err error) ([]byte, error) {
	if err != nil {
		return nil, err
	}
	defer response.Body.Close()
	body, readErr := io.ReadAll(io.LimitReader(response.Body, 4<<20))
	if readErr != nil {
		return nil, readErr
	}
	if response.StatusCode < http.StatusOK || response.StatusCode >= http.StatusMultipleChoices {
		return nil, fmt.Errorf("fetch external home listing: status %d", response.StatusCode)
	}
	return body, nil
}

var anchorRE = regexp.MustCompile(`(?is)<a\b([^>]*)>`)
var ariaLabelRE = regexp.MustCompile(`(?i)\baria-label="([^"]+)"`)
var hrefRE = regexp.MustCompile(`(?i)\bhref="(/blog/[^"]+)"`)

func ParseProductSchoolListing(document []byte) []Post {
	posts := make([]Post, 0)
	seen := make(map[string]struct{})
	for _, match := range anchorRE.FindAllSubmatch(document, -1) {
		attributes := string(match[1])
		titleMatch := ariaLabelRE.FindStringSubmatch(attributes)
		hrefMatch := hrefRE.FindStringSubmatch(attributes)
		if len(titleMatch) < 2 || len(hrefMatch) < 2 {
			continue
		}
		title := strings.TrimSpace(html.UnescapeString(titleMatch[1]))
		path := strings.TrimPrefix(html.UnescapeString(hrefMatch[1]), "/blog/")
		if title == "" || path == "" {
			continue
		}
		if _, exists := seen[path]; exists {
			continue
		}
		seen[path] = struct{}{}
		category := strings.Split(path, "/")[0]
		posts = append(posts, Post{
			Source: "productschool", ExternalID: path, Author: "Product School",
			Role: humanizeCategory(category), Content: title, Tags: []string{"#" + humanizeCategory(category)},
			URL: "https://productschool.com/blog/" + path, SourceOrder: len(posts),
		})
	}
	return posts
}

var indieStoryRE = regexp.MustCompile(`(?is)<a\b([^>]*story__text-link[^>]*)>\s*<h3\b[^>]*story__title[^>]*>(.*?)</h3>`)
var indieHrefRE = regexp.MustCompile(`(?i)\bhref="(/post/[^"]+)"`)
var indieAuthorRE = regexp.MustCompile(`(?is)class="[^"]*user-link__name[^\"]*"[^>]*>(.*?)</span>`)
var htmlTagRE = regexp.MustCompile(`(?is)<[^>]+>`)

// ParseIndieHackersListing extracts post cards from the public home page.
// Product links and navigation anchors are intentionally ignored.
func ParseIndieHackersListing(document []byte) []Post {
	posts := make([]Post, 0)
	seen := make(map[string]struct{})
	matches := indieStoryRE.FindAllSubmatchIndex(document, -1)
	for index, match := range matches {
		if len(match) < 6 {
			continue
		}
		attributes := string(document[match[2]:match[3]])
		hrefMatch := indieHrefRE.FindStringSubmatch(attributes)
		if len(hrefMatch) < 2 {
			continue
		}
		path := strings.TrimSpace(html.UnescapeString(hrefMatch[1]))
		path = strings.TrimPrefix(path, "/")
		if _, exists := seen[path]; exists {
			continue
		}
		title := cleanHTMLText(document[match[4]:match[5]])
		if title == "" {
			continue
		}
		end := len(document)
		if index+1 < len(matches) {
			end = matches[index+1][0]
		}
		chunk := document[match[1]:end]
		author := "Indie Hackers"
		if authorMatch := indieAuthorRE.FindSubmatch(chunk); len(authorMatch) > 1 {
			if value := cleanHTMLText(authorMatch[1]); value != "" {
				author = value
			}
		}
		seen[path] = struct{}{}
		posts = append(posts, Post{
			Source: "indiehackers", ExternalID: path, Author: author, Role: "Indie Hacker",
			Content: title, Tags: []string{"#IndieHackers"}, URL: "https://www.indiehackers.com/" + path,
			SourceOrder: len(posts),
		})
	}
	return posts
}

func cleanHTMLText(value []byte) string {
	value = htmlTagRE.ReplaceAll(value, []byte(" "))
	return strings.Join(strings.Fields(html.UnescapeString(string(value))), " ")
}

func humanizeCategory(value string) string {
	parts := strings.FieldsFunc(value, func(r rune) bool { return r == '-' || r == '_' })
	for index, part := range parts {
		if part == "ai" {
			parts[index] = "AI"
			continue
		}
		if len(part) > 0 {
			parts[index] = strings.ToUpper(part[:1]) + part[1:]
		}
	}
	return strings.Join(parts, " ")
}
