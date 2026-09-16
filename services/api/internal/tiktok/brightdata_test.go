package tiktok

import (
	"context"
	"io"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestFetcherBuildsBrightDataRequestAndNormalizesResults(t *testing.T) {
	var gotMethod, gotAuth, gotDataset string
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		gotMethod = r.Method
		gotAuth = r.Header.Get("Authorization")
		gotDataset = r.URL.Query().Get("dataset_id")
		body, _ := io.ReadAll(r.Body)
		if string(body) != `{"input":[{"url":"https://www.tiktok.com/explore"}]}` {
			t.Errorf("unexpected body: %s", body)
		}
		w.Header().Set("Content-Type", "application/json")
		_, _ = w.Write([]byte(`[{"id":"v-1","desc":"热门创作","videoUrl":"https://cdn.example/v-1.mp4","diggCount":321,"commentCount":12,"shareCount":8,"createTime":1710000000}]`))
	}))
	defer server.Close()

	fetcher := NewFetcher(server.Client(), "secret", "dataset-tiktok", "https://www.tiktok.com/explore")
	fetcher.endpoint = server.URL
	items, err := fetcher.Fetch(context.Background(), 10)
	if err != nil {
		t.Fatalf("Fetch() error = %v", err)
	}
	if gotMethod != http.MethodPost || gotAuth != "Bearer secret" || gotDataset != "dataset-tiktok" {
		t.Fatalf("request metadata = %s %s %s", gotMethod, gotAuth, gotDataset)
	}
	if len(items) != 1 || items[0].Platform != "douyin" || items[0].ExternalID != "v-1" || items[0].LikeCount != 321 || items[0].PlayURL == "" {
		t.Fatalf("unexpected items: %#v", items)
	}
}

func TestUnwrapResultsAcceptsBrightDataEnvelopes(t *testing.T) {
	for name, payload := range map[string]string{
		"data":    `{"data":[{"id":"1"}]}`,
		"results": `{"results":[{"id":"2"}]}`,
		"items":   `{"items":[{"id":"3"}]}`,
	} {
		t.Run(name, func(t *testing.T) {
			items, err := unwrapResults([]byte(payload))
			if err != nil || len(items) != 1 {
				t.Fatalf("unwrapResults() = %#v, %v", items, err)
			}
		})
	}
}

func TestFetcherRejectsMissingConfiguration(t *testing.T) {
	if _, err := NewFetcher(nil, "", "", "").Fetch(context.Background(), 20); err == nil {
		t.Fatal("expected missing configuration error")
	}
}
