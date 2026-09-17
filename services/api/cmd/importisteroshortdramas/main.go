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
	"creatorhub/api/internal/isteroshortdrama"
	"creatorhub/api/internal/shortdrama"
)

const defaultLimit = 20

func main() {
	authorization := strings.TrimSpace(os.Getenv("ISTERO_AUTHORIZATION"))
	token := strings.TrimSpace(os.Getenv("ISTERO_TOKEN"))
	query := strings.TrimSpace(os.Getenv("ISTERO_QUERY"))
	if query == "" {
		query = "短剧"
	}
	limit, err := envInt("ISTERO_IMPORT_LIMIT", defaultLimit, 1, 100)
	if err != nil {
		log.Fatal(err)
	}

	client := isteroshortdrama.NewClient(&http.Client{Timeout: 20 * time.Second}, authorization, token, query)
	dramas, err := client.Fetch(context.Background(), limit)
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
		"discovered": len(dramas),
		"imported":   len(dramas),
	}); err != nil {
		log.Fatal(err)
	}
}

func envInt(key string, fallback, min, max int) (int, error) {
	value := strings.TrimSpace(os.Getenv(key))
	if value == "" {
		return fallback, nil
	}
	parsed, err := strconv.Atoi(value)
	if err != nil {
		return 0, fmt.Errorf("%s must be an integer: %w", key, err)
	}
	if parsed < min || parsed > max {
		return 0, fmt.Errorf("%s must be between %d and %d", key, min, max)
	}
	return parsed, nil
}
