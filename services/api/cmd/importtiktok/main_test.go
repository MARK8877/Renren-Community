package main

import "testing"

func TestEnvLimit(t *testing.T) {
	tests := []struct {
		name     string
		value    string
		fallback int
		want     int
		wantErr  bool
	}{
		{name: "fallback", fallback: 20, want: 20},
		{name: "custom", value: "50", fallback: 20, want: 50},
		{name: "invalid", value: "0", fallback: 20, wantErr: true},
	}
	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			t.Setenv("TIKTOK_IMPORT_LIMIT", test.value)
			got, err := envLimit("TIKTOK_IMPORT_LIMIT", test.fallback)
			if test.wantErr {
				if err == nil {
					t.Fatal("expected error")
				}
				return
			}
			if err != nil || got != test.want {
				t.Fatalf("envLimit() = %d, %v; want %d", got, err, test.want)
			}
		})
	}
}
