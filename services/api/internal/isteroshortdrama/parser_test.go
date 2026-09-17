package isteroshortdrama

import "testing"

func TestParseResponseMapsAndDeduplicatesResources(t *testing.T) {
	body := []byte(`{
  "code": 200,
  "data": [
    {"title":"爱情短剧（12集）","url":"https://pan.quark.cn/s/one","time":"2024-08-31 00:31:09"},
    {"title":"重复资源","url":"https://pan.quark.cn/s/one","time":"2024-09-01 00:00:00"},
    {"title":"都市短剧","url":"https://pan.quark.cn/s/two","time":"2024-09-01 00:00:00"}
  ],
  "message":""
}`)

	result, err := ParseResponse(body)
	if err != nil {
		t.Fatalf("parse: %v", err)
	}
	if len(result) != 2 {
		t.Fatalf("len(result) = %d, want 2", len(result))
	}
	first := result[0]
	if first.SourceID != 100002 || first.SourceName != "ISTERO 全网短剧" {
		t.Fatalf("unexpected source: %#v", first)
	}
	if first.Name != "爱情短剧（12集）" || first.TotalEpisodes != 12 || first.UpdateTime != "2024-08-31 00:31:09" {
		t.Fatalf("unexpected metadata: %#v", first)
	}
	if first.ExternalID == "" || len(first.Episodes) != 1 || first.Episodes[0].URL != "https://pan.quark.cn/s/one" {
		t.Fatalf("resource was not preserved: %#v", first)
	}
}

func TestParseResponseRejectsAPIError(t *testing.T) {
	if _, err := ParseResponse([]byte(`{"code":403,"message":"Token鉴权失败","data":""}`)); err == nil {
		t.Fatal("expected API error")
	}
}
