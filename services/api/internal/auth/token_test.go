package auth

import (
	"testing"
	"time"
)

func TestTokenRoundTrip(t *testing.T) {
	manager := NewTokenManager([]byte("12345678901234567890123456789012"), time.Hour)
	token, _, err := manager.Create(42, "admin")
	if err != nil {
		t.Fatal(err)
	}
	claims, err := manager.Parse(token)
	if err != nil {
		t.Fatal(err)
	}
	if claims.UserID != 42 || claims.Role != "admin" {
		t.Fatalf("unexpected claims: %+v", claims)
	}
}

func TestRejectsChangedToken(t *testing.T) {
	manager := NewTokenManager([]byte("12345678901234567890123456789012"), time.Hour)
	token, _, _ := manager.Create(42, "user")
	if _, err := manager.Parse(token + "changed"); err == nil {
		t.Fatal("expected changed token to be rejected")
	}
}
