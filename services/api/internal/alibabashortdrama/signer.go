package alibabashortdrama

import (
	"crypto/hmac"
	"crypto/md5"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"sort"
	"strings"
)

func sign(params map[string]string, secret, method string) (string, error) {
	method = strings.ToLower(strings.TrimSpace(method))
	if method != "hmac" && method != "md5" && method != "hmac-sha256" {
		return "", fmt.Errorf("unsupported sign method %q", method)
	}
	keys := make([]string, 0, len(params))
	for key, value := range params {
		if key != "sign" && value != "" {
			keys = append(keys, key)
		}
	}
	sort.Strings(keys)
	var builder strings.Builder
	for _, key := range keys {
		builder.WriteString(key)
		builder.WriteString(params[key])
	}
	payload := []byte(builder.String())
	var digest []byte
	switch method {
	case "hmac":
		hasher := hmac.New(md5.New, []byte(secret))
		_, _ = hasher.Write(payload)
		digest = hasher.Sum(nil)
	case "hmac-sha256":
		hasher := hmac.New(sha256.New, []byte(secret))
		_, _ = hasher.Write(payload)
		digest = hasher.Sum(nil)
	case "md5":
		input := make([]byte, 0, len(secret)*2+len(payload))
		input = append(input, secret...)
		input = append(input, payload...)
		input = append(input, secret...)
		hash := md5.Sum(input)
		digest = hash[:]
	}
	return strings.ToUpper(hex.EncodeToString(digest)), nil
}
