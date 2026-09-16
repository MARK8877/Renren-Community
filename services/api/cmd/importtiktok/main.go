package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"os"
	"strconv"
	"strings"

	"creatorhub/api/internal/config"
	"creatorhub/api/internal/database"
	"creatorhub/api/internal/tiktok"
	"creatorhub/api/internal/video"
)

const defaultLimit = 20

func main() {
	limit, err := envLimit("TIKTOK_IMPORT_LIMIT", defaultLimit)
	if err != nil {
		log.Fatal(err)
	}
	fetcher := tiktok.NewFetcher(
		nil,
		os.Getenv("BRIGHTDATA_API_KEY"),
		os.Getenv("BRIGHTDATA_TIKTOK_DATASET_ID"),
		os.Getenv("TIKTOK_TRENDING_URL"),
	)
	items, err := fetcher.Fetch(context.Background(), limit)
	if err != nil {
		log.Fatal(err)
	}
	if len(items) == 0 {
		log.Fatal("Bright Data returned no playable TikTok videos")
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
	repository := video.NewRepository(db)
	for _, item := range items {
		if err := repository.Upsert(context.Background(), item); err != nil {
			log.Fatalf("upsert %s/%s: %v", item.Platform, item.ExternalID, err)
		}
	}
	if err := json.NewEncoder(os.Stdout).Encode(map[string]int{
		"discovered": len(items), "imported": len(items),
	}); err != nil {
		log.Fatal(err)
	}
}

func envLimit(key string, fallback int) (int, error) {
	value := strings.TrimSpace(os.Getenv(key))
	if value == "" {
		return fallback, nil
	}
	parsed, err := strconv.Atoi(value)
	if err != nil || parsed <= 0 || parsed > 100 {
		return 0, fmt.Errorf("%s must be an integer between 1 and 100", key)
	}
	return parsed, nil
}
