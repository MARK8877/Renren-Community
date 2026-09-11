package main

import (
	"context"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"log"
	"os"

	"creatorhub/api/internal/config"
	"creatorhub/api/internal/database"
	"creatorhub/api/internal/video"
)

func main() {
	platform := flag.String("platform", "", "source platform: youtube, x, douyin, or web")
	input := flag.String("input", "-", "JSON file from Apify, or - for stdin")
	flag.Parse()
	if *platform == "" {
		log.Fatal("-platform is required")
	}

	reader, closeReader, err := openInput(*input)
	if err != nil {
		log.Fatal(err)
	}
	defer closeReader()
	items, err := decodeItems(reader)
	if err != nil {
		log.Fatalf("decode input: %v", err)
	}
	normalized := make([]video.Video, 0, len(items))
	for _, raw := range items {
		if item, ok := video.Normalize(*platform, raw); ok {
			normalized = append(normalized, item)
		}
	}
	normalized = video.Filter(normalized, 0)
	if len(normalized) == 0 {
		log.Print("no videos matched the minimum likes threshold")
		return
	}

	cfg, err := config.Load()
	if err != nil {
		log.Fatalf("load config: %v", err)
	}
	db, err := database.OpenMySQL(context.Background(), cfg.Database)
	if err != nil {
		log.Fatalf("connect mysql: %v", err)
	}
	defer db.Close()
	repo := video.NewRepository(db)
	for _, item := range normalized {
		if err := repo.Upsert(context.Background(), item); err != nil {
			log.Fatalf("upsert %s/%s: %v", item.Platform, item.ExternalID, err)
		}
	}
	fmt.Printf("imported %d videos\n", len(normalized))
}

func openInput(path string) (io.Reader, func(), error) {
	if path == "-" {
		return os.Stdin, func() {}, nil
	}
	file, err := os.Open(path)
	if err != nil {
		return nil, nil, err
	}
	return file, func() { _ = file.Close() }, nil
}

func decodeItems(reader io.Reader) ([]map[string]any, error) {
	var payload json.RawMessage
	if err := json.NewDecoder(reader).Decode(&payload); err != nil {
		return nil, err
	}
	var items []map[string]any
	if err := json.Unmarshal(payload, &items); err == nil {
		return items, nil
	}
	var envelope struct {
		Items []map[string]any `json:"items"`
	}
	if err := json.Unmarshal(payload, &envelope); err != nil || envelope.Items == nil {
		return nil, errors.New("input must be a JSON array or an object with items")
	}
	return envelope.Items, nil
}
