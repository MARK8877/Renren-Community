package main

import (
	"strings"
	"testing"
)

func TestDecodeItemsAcceptsApifyItemsEnvelope(t *testing.T) {
	items, err := decodeItems(strings.NewReader(`{"items":[{"id":"1"}]}`))
	if err != nil {
		t.Fatal(err)
	}
	if len(items) != 1 || items[0]["id"] != "1" {
		t.Fatalf("unexpected items: %#v", items)
	}
}
