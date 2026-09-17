package shortdrama

import "testing"

func TestParseSearchAndDetailResponses(t *testing.T) {
	list, err := ParseSearchResponse([]byte(`{
      "code": 200,
      "msg": "success",
      "data": {
        "source": {"id": 2, "name": "资源站2"},
        "list": [{"n": 1, "id": 987, "name": "像素短剧", "pic": "https://img.test/poster.jpg", "type": "短剧", "total_episodes": 12}]
      }
    }`))
	if err != nil {
		t.Fatal(err)
	}
	if len(list.Items) != 1 || list.Items[0].ExternalID != "987" {
		t.Fatalf("unexpected list: %#v", list.Items)
	}
	if list.SourceID != 2 || list.SourceName != "资源站2" {
		t.Fatalf("unexpected source: %d/%q", list.SourceID, list.SourceName)
	}

	drama, err := ParseDetailResponse([]byte(`{
      "code": 200,
      "msg": "解析成功",
      "data": {
        "id": 987,
        "name": "像素短剧",
        "subtitle": "Pixel Story",
        "pic": "https://img.test/poster.jpg",
        "year": "2026",
        "area": "中国大陆",
        "language": "国语",
        "remarks": "HD高清",
        "actors": "甲,乙",
        "director": "丙",
        "douban_score": "8.1",
        "type": "短剧",
        "class": "都市",
        "duration": "12分钟",
        "total_episodes": 12,
        "update_time": "2026-09-17",
        "episodes": [{"title": "第1集", "url": "https://cdn.test/1.m3u8", "m3u8url": "https://play.test/1.m3u8"}]
      }
    }`))
	if err != nil {
		t.Fatal(err)
	}
	if drama.ExternalID != "987" || drama.Name != "像素短剧" || len(drama.Episodes) != 1 {
		t.Fatalf("unexpected drama: %#v", drama)
	}
	if drama.Episodes[0].M3U8URL != "https://play.test/1.m3u8" {
		t.Fatalf("unexpected episode: %#v", drama.Episodes[0])
	}
}

func TestParseSearchResponseRejectsAPIError(t *testing.T) {
	_, err := ParseSearchResponse([]byte(`{"code": 400, "msg": "失败", "data": {"msg": "请提供搜索关键字参数 msg="}}`))
	if err == nil {
		t.Fatal("expected API error")
	}
}
