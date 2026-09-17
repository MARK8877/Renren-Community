package shortdrama

import (
	"encoding/json"
	"time"
)

type Episode struct {
	Episode  int    `json:"episode,omitempty"`
	Title    string `json:"title"`
	PwdID    string `json:"pwd_id,omitempty"`
	FID      string `json:"fid,omitempty"`
	FIDToken string `json:"fid_token,omitempty"`
	Size     int64  `json:"size,omitempty"`
	Duration int64  `json:"duration,omitempty"`
	URL      string `json:"url"`
	M3U8URL  string `json:"m3u8url"`
}

type SearchItem struct {
	N             int
	ExternalID    string
	Name          string
	Subtitle      string
	Remarks       string
	PosterURL     string
	Year          string
	Area          string
	Language      string
	Actors        string
	Director      string
	Score         string
	Type          string
	Class         string
	Duration      string
	Blurb         string
	Content       string
	TotalEpisodes int
	UpdateTime    string
}

type SearchResult struct {
	SourceID   int
	SourceName string
	Items      []SearchItem
}

type Drama struct {
	SourceID      int
	SourceName    string
	ExternalID    string
	Name          string
	Subtitle      string
	Remarks       string
	PosterURL     string
	Year          string
	Area          string
	Language      string
	Actors        string
	Director      string
	Score         string
	Type          string
	Class         string
	Duration      string
	Blurb         string
	Content       string
	TotalEpisodes int
	UpdateTime    string
	Episodes      []Episode
}

// DramaRecord is the persisted representation returned by repository queries.
type DramaRecord struct {
	ID uint64
	Drama
	ScrapedAt time.Time
}

func (d Drama) episodesJSON() ([]byte, error) {
	episodes := d.Episodes
	if episodes == nil {
		episodes = []Episode{}
	}
	return json.Marshal(episodes)
}
