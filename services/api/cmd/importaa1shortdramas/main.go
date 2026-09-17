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

	"creatorhub/api/internal/aa1shortdrama"
	"creatorhub/api/internal/config"
	"creatorhub/api/internal/database"
	"creatorhub/api/internal/shortdrama"
)

const (
	defaultPageSize = 20
	defaultLimit    = 20
)

func main() {
	query := strings.TrimSpace(os.Getenv("AA1_QUERY"))
	pageSize, err := envInt("AA1_PAGE_SIZE", defaultPageSize, 1, 100)
	if err != nil {
		log.Fatal(err)
	}
	limit, err := envInt("AA1_IMPORT_LIMIT", defaultLimit, 1, 100)
	if err != nil {
		log.Fatal(err)
	}

	client := aa1shortdrama.NewClient(&http.Client{Timeout: 20 * time.Second}, query, pageSize)
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
