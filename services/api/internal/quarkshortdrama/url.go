package quarkshortdrama

import (
	"fmt"
	"net/url"
	"strings"
)

// ParseShareURL accepts only public HTTPS Quark share links.
func ParseShareURL(raw string) (pwdID, rootFID string, err error) {
	u, err := url.Parse(strings.TrimSpace(raw))
	if err != nil || u.Scheme != "https" || strings.ToLower(u.Hostname()) != "pan.quark.cn" {
		return "", "", fmt.Errorf("share URL must be an HTTPS pan.quark.cn link")
	}
	parts := strings.Split(strings.Trim(u.Path, "/"), "/")
	if len(parts) < 2 || parts[0] != "s" || strings.TrimSpace(parts[1]) == "" {
		return "", "", fmt.Errorf("invalid Quark share URL")
	}
	pwdID = parts[1]
	// The root fid is optional in the URL hash; the token response supplies it.
	if i := strings.Index(u.Fragment, "/list/share/"); i >= 0 {
		rootFID = strings.Trim(strings.TrimPrefix(u.Fragment[i+len("/list/share/"):], "/"), "#")
	}
	return pwdID, rootFID, nil
}
