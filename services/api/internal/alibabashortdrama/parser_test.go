package alibabashortdrama

import "testing"

func TestParseResponseMapsDramaList(t *testing.T) {
	body := []byte(`{
  "alibaba_shuqi_content_backend_drama_searchorexport_response": {
    "data": {"total": 1, "list": {"drama_list_biz_response": [{
      "drama_id": 123,
      "drama_name": "哆啦A梦",
      "category_name": "奇幻",
      "tag_names": "热血,冒险",
      "introduction": "简介内容",
      "cover_url": "https://img.example/cover.jpg",
      "total_episodes": 12,
      "update_status": 2,
      "drama_status": 1,
      "drama_channel": 3,
      "cp_name": "书旗",
      "category_id": 9,
      "corner_tag": 303,
      "top_class": 1314,
      "original_top_class": 1314,
      "original_id": 123
    }]}},
    "state": 200,
    "message": "success"
  }
}`)

	result, err := ParseResponse(body)
	if err != nil {
		t.Fatalf("parse: %v", err)
	}
	if len(result) != 1 {
		t.Fatalf("len(result) = %d, want 1", len(result))
	}
	drama := result[0]
	if drama.ExternalID != "123" || drama.Name != "哆啦A梦" {
		t.Fatalf("unexpected identity: %#v", drama)
	}
	if drama.PosterURL != "https://img.example/cover.jpg" || drama.TotalEpisodes != 12 {
		t.Fatalf("unexpected metadata: %#v", drama)
	}
	if drama.SourceID != 71096 || drama.SourceName != "书旗短剧" {
		t.Fatalf("unexpected source: %#v", drama)
	}
}

func TestParseResponseRejectsAPIError(t *testing.T) {
	body := []byte(`{"alibaba_shuqi_content_backend_drama_searchorexport_response":{"state":400,"message":"bad request"}}`)
	if _, err := ParseResponse(body); err == nil {
		t.Fatal("expected API error")
	}
}
