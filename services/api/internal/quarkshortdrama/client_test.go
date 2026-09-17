package quarkshortdrama

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestCollectFiltersVideosAndRefreshesPreview(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		switch r.URL.Path {
		case "/1/clouddrive/share/sharepage/token":
			_ = json.NewEncoder(w).Encode(map[string]any{"code": 0, "data": map[string]any{"stoken": "temporary", "title": "测试短剧", "first_fid": "root"}})
		case "/1/clouddrive/share/sharepage/detail":
			_ = json.NewEncoder(w).Encode(map[string]any{"code": 0, "data": map[string]any{"has_more": false, "list": []any{
				map[string]any{"fid": "v1", "fid_token": "ft1", "file_name": "第2集.mp4", "format_type": "video/mp4", "size": 10},
				map[string]any{"fid": "i1", "file_name": "封面.jpg", "format_type": "image/jpeg"},
			}}})
		case "/1/clouddrive/share/sharepage/video_preview":
			if r.URL.Query().Get("fid_token") != "ft1" || r.Header.Get("x-clouddrive-st") != "temporary" {
				t.Errorf("preview request missing share identifiers")
			}
			_ = json.NewEncoder(w).Encode(map[string]any{"code": 0, "data": map[string]any{"duration": 123, "play_info": map[string]string{"url": "https://cdn.example/1.m3u8"}}})
		default:
			http.NotFound(w, r)
		}
	}))
	defer server.Close()

	drama, err := NewClient(server.Client(), server.URL).Collect(context.Background(), "https://pan.quark.cn/s/demo#/list/share/root", 20)
	if err != nil {
		t.Fatal(err)
	}
	if drama.Name != "测试短剧" || len(drama.Episodes) != 1 || drama.Episodes[0].Episode != 2 || drama.Episodes[0].M3U8URL == "" {
		t.Fatalf("unexpected drama: %+v", drama)
	}
}

func TestCollectKeepsEpisodeWhenPreviewTemporarilyUnavailable(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		switch r.URL.Path {
		case "/1/clouddrive/share/sharepage/token":
			_ = json.NewEncoder(w).Encode(map[string]any{"code": 0, "data": map[string]any{"stoken": "temporary", "title": "测试短剧", "first_fid": "root"}})
		case "/1/clouddrive/share/sharepage/detail":
			_ = json.NewEncoder(w).Encode(map[string]any{"code": 0, "data": map[string]any{"has_more": false, "list": []any{
				map[string]any{"fid": "v1", "fid_token": "ft1", "file_name": "第1集.mp4", "format_type": "video/mp4", "duration": 100},
				map[string]any{"fid": "v2", "fid_token": "ft2", "file_name": "第2集.mp4", "format_type": "video/mp4", "duration": 110},
			}}})
		case "/1/clouddrive/share/sharepage/video_preview":
			if r.URL.Query().Get("fid") == "v1" { http.Error(w, "token invalid", http.StatusForbidden); return }
			_ = json.NewEncoder(w).Encode(map[string]any{"code": 0, "data": map[string]any{"duration": 110, "play_info": map[string]string{"url": "https://cdn.example/2.m3u8"}}})
		default:
			http.NotFound(w, r)
		}
	}))
	defer server.Close()

	drama, err := NewClient(server.Client(), server.URL).Collect(context.Background(), "https://pan.quark.cn/s/demo#/list/share/root", 20)
	if err != nil { t.Fatal(err) }
	if len(drama.Episodes) != 2 { t.Fatalf("episode count = %d, want 2", len(drama.Episodes)) }
	if drama.Episodes[0].Duration != 100 || drama.Episodes[0].M3U8URL != "" { t.Fatalf("unavailable episode was not preserved safely: %+v", drama.Episodes[0]) }
}
