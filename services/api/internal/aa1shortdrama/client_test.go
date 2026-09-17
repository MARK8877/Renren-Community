package aa1shortdrama

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestClientFetchUsesDocumentedQuery(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodGet {
			t.Errorf("method = %s, want GET", r.Method)
		}
		query := r.URL.Query()
		if query.Get("path") != "movies" || query.Get("page") != "1" || query.Get("limit") != "1" || query.Get("name") != "总裁" {
			t.Errorf("unexpected query: %v", query)
		}
		_, _ = w.Write([]byte(`{"code":0,"message":"Success","data":{"total":1,"rows":[{"id":1,"name":"测试短剧（3集）","link":"https://pan.quark.cn/s/test"}]}}`))
	}))
	defer server.Close()

	client := NewClient(server.Client(), "总裁", 1)
	client.endpoint = server.URL
	result, err := client.Fetch(context.Background(), 1)
	if err != nil {
		t.Fatalf("fetch: %v", err)
	}
	if len(result) != 1 || result[0].ExternalID != "1" {
		t.Fatalf("unexpected result: %#v", result)
	}
}
