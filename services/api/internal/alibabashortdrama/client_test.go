package alibabashortdrama

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestClientFetchPostsSignedPagedRequest(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			t.Errorf("method = %s, want POST", r.Method)
		}
		if err := r.ParseForm(); err != nil {
			t.Fatalf("parse form: %v", err)
		}
		for _, key := range []string{"app_key", "sign", "timestamp", "page", "page_size", "top_class"} {
			if r.Form.Get(key) == "" {
				t.Errorf("missing form field %q", key)
			}
		}
		if r.Form.Get("app_key") != "app-key" || r.Form.Get("page") != "1" || r.Form.Get("page_size") != "1" {
			t.Errorf("unexpected form: %v", r.Form)
		}
		w.Header().Set("Content-Type", "application/json")
		_, _ = w.Write([]byte(`{"alibaba_shuqi_content_backend_drama_searchorexport_response":{"data":{"total":1,"list":{"drama_list_biz_response":[{"drama_id":9,"drama_name":"测试短剧","introduction":"简介","total_episodes":3}]}},"state":200,"message":"success"}}`))
	}))
	defer server.Close()

	client := NewClient(server.Client(), "app-key", "app-secret", "短剧", 1)
	client.endpoint = server.URL
	result, err := client.Fetch(context.Background(), 1)
	if err != nil {
		t.Fatalf("fetch: %v", err)
	}
	if len(result) != 1 || result[0].ExternalID != "9" {
		t.Fatalf("unexpected result: %#v", result)
	}
}

func TestClientFetchRequiresCredentials(t *testing.T) {
	client := NewClient(nil, "", "", "短剧", 20)
	if _, err := client.Fetch(context.Background(), 1); err == nil {
		t.Fatal("expected credentials error")
	}
}
