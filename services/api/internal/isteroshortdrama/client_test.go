package isteroshortdrama

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestClientFetchSendsFormAndAuthorization(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			t.Errorf("method = %s, want POST", r.Method)
		}
		if got := r.Header.Get("Authorization"); got != "Bearer auth-value" {
			t.Errorf("authorization = %q", got)
		}
		if got := r.Header.Get("Content-Type"); got != "application/x-www-form-urlencoded;charset=UTF-8" {
			t.Errorf("content type = %q", got)
		}
		if err := r.ParseForm(); err != nil {
			t.Fatalf("parse form: %v", err)
		}
		if r.Form.Get("text") != "爱情" || r.Form.Get("token") != "token-value" {
			t.Errorf("unexpected form: %v", r.Form)
		}
		_, _ = w.Write([]byte(`{"code":200,"data":[{"title":"测试短剧（3集）","url":"https://pan.quark.cn/s/test","time":"2024-01-01 00:00:00"}],"message":""}`))
	}))
	defer server.Close()

	client := NewClient(server.Client(), "auth-value", "token-value", "爱情")
	client.endpoint = server.URL
	result, err := client.Fetch(context.Background(), 1)
	if err != nil {
		t.Fatalf("fetch: %v", err)
	}
	if len(result) != 1 || result[0].ExternalID == "" {
		t.Fatalf("unexpected result: %#v", result)
	}
}

func TestClientFetchRequiresCredential(t *testing.T) {
	client := NewClient(nil, "", "", "短剧")
	if _, err := client.Fetch(context.Background(), 1); err == nil {
		t.Fatal("expected credential error")
	}
}

func TestClientFetchIncludesUpstreamErrorMessage(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusForbidden)
		_, _ = w.Write([]byte(`{"code":403,"message":"IP 不在白名单"}`))
	}))
	defer server.Close()

	client := NewClient(server.Client(), "auth-value", "", "短剧")
	client.endpoint = server.URL
	if _, err := client.Fetch(context.Background(), 1); err == nil || err.Error() != "ISTERO API HTTP 403: IP 不在白名单" {
		t.Fatalf("unexpected error: %v", err)
	}
}
