package quarkshortdrama

import "testing"

func TestParseShareURL(t *testing.T) {
	pwd, fid, err := ParseShareURL("https://pan.quark.cn/s/db532a8e9950#/list/share/3164a37f94734cad87356081c609f154")
	if err != nil || pwd != "db532a8e9950" || fid != "3164a37f94734cad87356081c609f154" {
		t.Fatalf("ParseShareURL() = %q, %q, %v", pwd, fid, err)
	}
	for _, raw := range []string{"http://pan.quark.cn/s/demo", "https://example.com/s/demo", "https://pan.quark.cn/share/demo"} {
		if _, _, err := ParseShareURL(raw); err == nil {
			t.Errorf("ParseShareURL(%q) unexpectedly succeeded", raw)
		}
	}
}
