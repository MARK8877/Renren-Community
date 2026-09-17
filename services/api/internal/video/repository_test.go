package video

import (
	"strings"
	"testing"
)

func TestListQueryPrioritizesLatestScrapes(t *testing.T) {
	query, args := listQuery("", 1, 20)
	if !strings.Contains(query, "ORDER BY scraped_at DESC, published_at DESC, id DESC") {
		t.Fatalf("query does not prioritize scraped_at: %s", query)
	}
	if len(args) != 2 || args[0] != 20 || args[1] != 0 {
		t.Fatalf("unexpected pagination args: %#v", args)
	}
}
