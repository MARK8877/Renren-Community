package main

import (
	"bufio"
	"context"
	"encoding/json"
	"log"
	"os"
	"strings"

	"creatorhub/api/internal/config"
	"creatorhub/api/internal/database"
	"creatorhub/api/internal/homefeed"
)

func main() {
	loadDotEnv(".env")
	cfg, err := config.Load()
	if err != nil {
		log.Fatal(err)
	}
	posts, err := homefeed.NewIndieHackersFetcher(nil, os.Getenv("BRIGHTDATA_API_KEY"), os.Getenv("BRIGHTDATA_UNLOCKER_ZONE")).Fetch(context.Background())
	if err != nil {
		log.Fatal(err)
	}
	if len(posts) == 0 {
		log.Fatal("Indie Hackers page returned no posts")
	}
	db, err := database.OpenMySQL(context.Background(), cfg.Database)
	if err != nil {
		log.Fatalf("connect mysql: %v", err)
	}
	defer db.Close()
	repository := homefeed.NewRepository(db)
	for _, post := range posts {
		if err := repository.Upsert(context.Background(), post); err != nil {
			log.Fatalf("upsert %s/%s: %v", post.Source, post.ExternalID, err)
		}
	}
	if err := json.NewEncoder(os.Stdout).Encode(map[string]int{"discovered": len(posts), "imported": len(posts)}); err != nil {
		log.Fatal(err)
	}
}

// loadDotEnv keeps the one-off importer usable from a clean shell while
// preserving explicitly exported environment variables.
func loadDotEnv(path string) {
	file, err := os.Open(path)
	if err != nil {
		return
	}
	defer file.Close()
	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		key, value, ok := strings.Cut(line, "=")
		if !ok || strings.TrimSpace(key) == "" || os.Getenv(strings.TrimSpace(key)) != "" {
			continue
		}
		value = strings.Trim(strings.TrimSpace(value), "\"'")
		_ = os.Setenv(strings.TrimSpace(key), value)
	}
}
