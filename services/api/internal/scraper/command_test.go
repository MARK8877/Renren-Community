package scraper

import (
	"reflect"
	"strings"
	"testing"
)

func TestParseStatsUsesLatestJSONLine(t *testing.T) {
	result, err := parseStats("warning\n{\"discovered\":3,\"accepted\":3,\"imported\":2}\n")
	if err != nil {
		t.Fatal(err)
	}
	if result.Discovered != 3 || result.Processed != 2 {
		t.Fatalf("unexpected result: %+v", result)
	}
}

func TestParseStatsAllowsMissingFields(t *testing.T) {
	result, err := parseStats(`{"discovered": 5}`)
	if err != nil {
		t.Fatal(err)
	}
	if result.Discovered != 5 || result.Processed != 0 {
		t.Fatalf("unexpected result: %+v", result)
	}
}

func TestParseStatsRejectsInvalidOutput(t *testing.T) {
	if _, err := parseStats("not json"); err == nil {
		t.Fatal("parseStats should reject output without a statistics object")
	}
}

func TestPythonCommandArgs(t *testing.T) {
	command := NewPythonCommand("/srv/api", "/srv/api/scraper/.venv/bin/python", "scraper/free_video_scraper.py", 50)
	want := []string{"/srv/api/scraper/.venv/bin/python", "scraper/free_video_scraper.py", "--pexels", "--pexels-limit", "50", "--import"}
	if got := command.args(); !reflect.DeepEqual(got, want) {
		t.Fatalf("args = %#v, want %#v", got, want)
	}
}

func TestTruncateKeepsErrorBounded(t *testing.T) {
	if got := truncate(strings.Repeat("x", 5), 3); got != "xxx..." {
		t.Fatalf("truncate = %q", got)
	}
}
