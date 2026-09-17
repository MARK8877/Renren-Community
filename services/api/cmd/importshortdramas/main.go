package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"strconv"
	"strings"
	"time"

	"creatorhub/api/internal/config"
	"creatorhub/api/internal/database"
	"creatorhub/api/internal/shortdrama"
)

const (
	defaultQuery  = "短剧"
	defaultSource = 1
	defaultLimit  = 20
)

func main() {
	query := envString("YAOHUD_QUERY", defaultQuery)
	source, err := envInt("YAOHUD_SOURCE", defaultSource)
	if err != nil {
		log.Fatal(err)
	}
	limit, err := envInt("YAOHUD_IMPORT_LIMIT", defaultLimit)
	if err != nil {
		log.Fatal(err)
	}
	key := strings.TrimSpace(os.Getenv("YAOHUD_API_KEY"))
	if key == "" {
		log.Fatal("YAOHUD_API_KEY is required; create one in the Yaohu console")
	}

	fetcher := shortdrama.NewClient(&http.Client{Timeout: 20 * time.Second}, key, query, source)
	dramas, err := fetcher.Fetch(context.Background(), limit)
	if err != nil {
		log.Fatal(err)
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
	repository := shortdrama.NewRepository(db)
	scrapedAt := time.Now().UTC()
	for _, drama := range dramas {
		if err := repository.Upsert(context.Background(), drama, scrapedAt); err != nil {
			log.Fatalf("upsert %s: %v", drama.ExternalID, err)
		}
	}
	if err := json.NewEncoder(os.Stdout).Encode(map[string]int{
		"discovered": len(dramas), "imported": len(dramas),
	}); err != nil {
		log.Fatal(err)
	}
}

func envString(key, fallback string) string {
	if value := strings.TrimSpace(os.Getenv(key)); value != "" {
		return value
	}
	return fallback
}

func envInt(key string, fallback int) (int, error) {
	value := strings.TrimSpace(os.Getenv(key))
	if value == "" {
		return fallback, nil
	}
	parsed, err := strconv.Atoi(value)
	if err != nil {
		return 0, fmt.Errorf("%s must be an integer: %w", key, err)
	}
	if key == "YAOHUD_SOURCE" && (parsed < 1 || parsed > 4) {
		return 0, fmt.Errorf("%s must be between 1 and 4", key)
	}
	if key == "YAOHUD_IMPORT_LIMIT" && (parsed < 1 || parsed > 100) {
		return 0, fmt.Errorf("%s must be between 1 and 100", key)
	}
	return parsed, nil
}
