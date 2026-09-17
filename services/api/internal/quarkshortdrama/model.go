package quarkshortdrama

// Episode is the metadata needed to refresh a Quark playback URL later.
// FIDToken is a share-scoped identifier and is not an access credential.
type Episode struct {
	Episode  int    `json:"episode"`
	Title    string `json:"title"`
	PwdID    string `json:"pwd_id"`
	FID      string `json:"fid"`
	FIDToken string `json:"fid_token"`
	Size     int64  `json:"size,omitempty"`
	Duration int64  `json:"duration,omitempty"`
	URL      string `json:"url,omitempty"`
	M3U8URL  string `json:"m3u8url,omitempty"`
}

type Drama struct {
	ExternalID string
	Name       string
	UpdateTime string
	Episodes   []Episode
}

type Preview struct {
	URL      string
	Duration int64
}
