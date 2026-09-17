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
	"creatorhub/api/internal/quarkshortdrama"
	"creatorhub/api/internal/shortdrama"
)

const (
	defaultImportLimit = 1000
	quarkSourceID      = 100003
)

type importConfig struct {
	ShareURL, APIHost string
	Limit             int
}

func loadImportConfig() (importConfig, error) {
	shareURL := strings.TrimSpace(os.Getenv("QUARK_SHARE_URL"))
	if shareURL == "" {
		return importConfig{}, fmt.Errorf("QUARK_SHARE_URL is required")
	}
	if _, _, err := quarkshortdrama.ParseShareURL(shareURL); err != nil {
		return importConfig{}, err
	}
	limit, err := envInt("QUARK_IMPORT_LIMIT", defaultImportLimit, 1, 1000)
	if err != nil {
		return importConfig{}, err
	}
	host := strings.TrimRight(strings.TrimSpace(os.Getenv("QUARK_API_HOST")), "/")
	if host == "" {
		host = "https://drive-m.quark.cn"
	}
	return importConfig{ShareURL: shareURL, APIHost: host, Limit: limit}, nil
}

func main() {
	cfg, err := loadImportConfig()
	if err != nil {
		log.Fatal(err)
	}
	client := quarkshortdrama.NewClient(&http.Client{Timeout: 30 * time.Second}, cfg.APIHost)
	drama, err := client.Collect(context.Background(), cfg.ShareURL, cfg.Limit)
	if err != nil {
		log.Fatal(err)
	}
	persisted := shortdrama.Drama{SourceID: quarkSourceID, SourceName: "夸克公开分享", ExternalID: drama.ExternalID, Name: drama.Name, UpdateTime: drama.UpdateTime, TotalEpisodes: len(drama.Episodes), Episodes: make([]shortdrama.Episode, 0, len(drama.Episodes))}
	for _, ep := range drama.Episodes {
		persisted.Episodes = append(persisted.Episodes, shortdrama.Episode{Episode: ep.Episode, Title: ep.Title, PwdID: ep.PwdID, FID: ep.FID, FIDToken: ep.FIDToken, Size: ep.Size, Duration: ep.Duration, URL: ep.URL, M3U8URL: ep.M3U8URL})
	}
	appCfg, err := config.Load()
	if err != nil {
		log.Fatal(err)
	}
	db, err := database.OpenMySQL(context.Background(), appCfg.Database)
	if err != nil {
		log.Fatal(err)
	}
	defer db.Close()
	if err := shortdrama.NewRepository(db).Upsert(context.Background(), persisted, time.Now().UTC()); err != nil {
		log.Fatal(err)
	}
	if err := json.NewEncoder(os.Stdout).Encode(map[string]int{"discovered": len(drama.Episodes), "imported": 1}); err != nil {
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
