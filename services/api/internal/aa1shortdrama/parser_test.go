package aa1shortdrama

import "testing"

func TestParseResponseMapsRowsToShortDramas(t *testing.T) {
	body := []byte(`{
  "code": 0,
  "message": "Success",
  "data": {"total": 1, "rows": [{
    "id": 7929,
    "name": "为退婚，我把冰山总裁祸害哭了（78集）",
    "createAt": "1680419465",
    "updateAt": "1680419466",
    "link": "https://pan.quark.cn/s/example"
  }]}
}`)

	result, err := ParseResponse(body)
	if err != nil {
		t.Fatalf("parse: %v", err)
	}
	if len(result) != 1 {
		t.Fatalf("len(result) = %d, want 1", len(result))
	}
	drama := result[0]
	if drama.SourceID != 100001 || drama.SourceName != "AA1 免费短剧 API" {
		t.Fatalf("unexpected source: %#v", drama)
	}
	if drama.ExternalID != "7929" || drama.Name != "为退婚，我把冰山总裁祸害哭了（78集）" {
		t.Fatalf("unexpected identity: %#v", drama)
	}
	if drama.TotalEpisodes != 78 || drama.UpdateTime != "1680419466" {
		t.Fatalf("unexpected metadata: %#v", drama)
	}
	if len(drama.Episodes) != 1 || drama.Episodes[0].URL != "https://pan.quark.cn/s/example" {
		t.Fatalf("resource link was not preserved: %#v", drama.Episodes)
	}
}

func TestParseResponseRejectsAPIError(t *testing.T) {
	body := []byte(`{"code":500,"message":"failed","data":null}`)
	if _, err := ParseResponse(body); err == nil {
		t.Fatal("expected API error")
	}
}

func TestParseResponseRejectsHTMLUpstreamResponse(t *testing.T) {
	if _, err := ParseResponse([]byte("<html><body>domain for sale</body></html>")); err == nil {
		t.Fatal("expected non-JSON upstream error")
	}
}
