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
	defaultLibraryURL = "http://[::1]:8999/api/ui/dramas?revision=0"
	localSourceID     = 8999
	localSourceName   = "果果剧库"
)

type libraryResponse struct {
	Data []libraryDrama `json:"data"`
}

type libraryDrama struct {
	ID            string          `json:"id"`
	Source        string          `json:"source"`
	SourceID      string          `json:"sourceId"`
	Title         string          `json:"title"`
	Name          string          `json:"name"`
	Desc          string          `json:"desc"`
	Intro         string          `json:"intro"`
	CoverURL      string          `json:"coverUrl"`
	Cover         string          `json:"cover"`
	TotalEpisode  json.RawMessage `json:"totalEpisode"`
	EpisodeCount  json.RawMessage `json:"episodeCount"`
	CategoryName  string          `json:"categoryName"`
	TypeName      string          `json:"typeName"`
	Score         string          `json:"score"`
	OnlineDate    string          `json:"onlineDate"`
	Remark        string          `json:"remark"`
	Heat          string          `json:"heat"`
	Views         string          `json:"views"`
	ReleaseStatus string          `json:"releaseStatus"`
	Tags          []string        `json:"tags"`
}

type openResponse struct {
	Session  string           `json:"session"`
	Episodes []libraryEpisode `json:"episodes"`
}

type libraryEpisode struct {
	Index     int    `json:"index"`
	Episode   string `json:"episode"`
	Title     string `json:"title"`
	ChapterID string `json:"chapterId"`
	Number    int    `json:"number"`
}

func main() {
	ctx := context.Background()
	client := &http.Client{Timeout: 30 * time.Second}
	endpoint := envString("LOCAL_DRAMA_LIBRARY_URL", defaultLibraryURL)
	limit := envInt("LOCAL_DRAMA_IMPORT_LIMIT", 10)
	if limit < 1 || limit > 100 {
		log.Fatalf("LOCAL_DRAMA_IMPORT_LIMIT must be between 1 and 100")
	}

	var payload libraryResponse
	if err := getJSON(ctx, client, endpoint, &payload); err != nil {
		log.Fatalf("read local drama library: %v", err)
	}
	selected := make([]libraryDrama, 0, limit)
	for _, drama := range payload.Data {
		if drama.Source != "hongguo" {
			continue
		}
		selected = append(selected, drama)
		if len(selected) == limit {
			break
		}
	}
	if len(selected) == 0 {
		log.Fatal("local drama library returned no hongguo dramas")
	}

	cfg, err := config.Load()
	if err != nil {
		log.Fatalf("load config: %v", err)
	}
	db, err := database.OpenMySQL(ctx, cfg.Database)
	if err != nil {
		log.Fatalf("connect mysql: %v", err)
	}
	defer db.Close()
	repository := shortdrama.NewRepository(db)
	imported := 0
	batchTime := time.Now().UTC()
	for index, sourceDrama := range selected {
		episodes, err := fetchEpisodes(ctx, client, sourceDrama.ID)
		if err != nil {
			log.Printf("read episodes for %s: %v", sourceDrama.ID, err)
		}
		drama := toDrama(sourceDrama, episodes)
		// Keep the source order when the API sorts newly collected rows by scraped_at.
		scrapedAt := batchTime.Add(time.Duration(len(selected)-index) * time.Millisecond)
		if err := repository.Upsert(ctx, drama, scrapedAt); err != nil {
			log.Fatalf("upsert %s: %v", drama.ExternalID, err)
		}
		imported++
	}

	result := map[string]int{"discovered": len(selected), "imported": imported}
	if err := json.NewEncoder(os.Stdout).Encode(result); err != nil {
		log.Fatal(err)
	}
}

func fetchEpisodes(ctx context.Context, client *http.Client, dramaID string) ([]shortdrama.Episode, error) {
	body, err := json.Marshal(map[string]any{"dramaId": dramaID, "resume": false})
	if err != nil {
		return nil, err
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, "http://[::1]:8999/api/ui/playback/open", strings.NewReader(string(body)))
	if err != nil {
		return nil, err
	}
	req.Header.Set("Content-Type", "application/json")
	var result openResponse
	if err := doJSON(client, req, &result); err != nil {
		return nil, err
	}
	if result.Session != "" {
		closeSession(ctx, client, result.Session)
	}
	episodes := make([]shortdrama.Episode, 0, len(result.Episodes))
	for position, episode := range result.Episodes {
		number := episode.Number
		if number == 0 {
			number, _ = strconv.Atoi(strings.TrimSpace(episode.Episode))
		}
		if number == 0 {
			number = episode.Index
		}
		if number == 0 {
			number = position + 1
		}
		episodes = append(episodes, shortdrama.Episode{Episode: number, Title: episode.Title, FID: episode.ChapterID})
	}
	return episodes, nil
}

func closeSession(ctx context.Context, client *http.Client, session string) {
	body, _ := json.Marshal(map[string]string{"session": session, "action": "close"})
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, "http://[::1]:8999/api/ui/playback/control", strings.NewReader(string(body)))
	if err != nil {
		return
	}
	req.Header.Set("Content-Type", "application/json")
	_, _ = client.Do(req)
}

func toDrama(source libraryDrama, episodes []shortdrama.Episode) shortdrama.Drama {
	name := strings.TrimSpace(source.Title)
	if name == "" {
		name = strings.TrimSpace(source.Name)
	}
	poster := strings.TrimSpace(source.CoverURL)
	if poster == "" {
		poster = strings.TrimSpace(source.Cover)
	}
	total := atoiFirst(rawText(source.TotalEpisode), rawText(source.EpisodeCount))
	if total == 0 {
		total = len(episodes)
	}
	return shortdrama.Drama{
		SourceID:      localSourceID,
		SourceName:    localSourceName,
		ExternalID:    source.ID,
		Name:          name,
		Remarks:       source.Remark,
		PosterURL:     poster,
		Year:          source.OnlineDate,
		Score:         source.Score,
		Type:          source.TypeName,
		Class:         source.CategoryName,
		Blurb:         source.Desc,
		Content:       source.Intro,
		TotalEpisodes: total,
		UpdateTime:    source.OnlineDate,
		Episodes:      episodes,
	}
}

func rawText(value json.RawMessage) string {
	if len(value) == 0 || string(value) == "null" {
		return ""
	}
	var text string
	if json.Unmarshal(value, &text) == nil {
		return text
	}
	return strings.Trim(string(value), "\\\"")
}

func getJSON(ctx context.Context, client *http.Client, endpoint string, target any) error {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, endpoint, nil)
	if err != nil {
		return err
	}
	return doJSON(client, req, target)
}

func doJSON(client *http.Client, req *http.Request, target any) error {
	response, err := client.Do(req)
	if err != nil {
		return err
	}
	defer response.Body.Close()
	if response.StatusCode < 200 || response.StatusCode >= 300 {
		return fmt.Errorf("HTTP %s", response.Status)
	}
	return json.NewDecoder(response.Body).Decode(target)
}

func atoiFirst(values ...string) int {
	for _, value := range values {
		if parsed, err := strconv.Atoi(strings.TrimSpace(value)); err == nil && parsed > 0 {
			return parsed
		}
	}
	return 0
}

func envString(key, fallback string) string {
	if value := strings.TrimSpace(os.Getenv(key)); value != "" {
		return value
	}
	return fallback
}

func envInt(key string, fallback int) int {
	if value := strings.TrimSpace(os.Getenv(key)); value != "" {
		parsed, err := strconv.Atoi(value)
		if err == nil {
			return parsed
		}
	}
	return fallback
}
