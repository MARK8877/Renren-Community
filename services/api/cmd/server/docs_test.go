package main

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestDocumentationRoutes(t *testing.T) {
	mux := http.NewServeMux()
	registerDocsRoutes(mux)

	tests := []struct {
		name        string
		path        string
		contentType string
		contains    string
	}{
		{
			name:        "openapi document",
			path:        "/openapi.yaml",
			contentType: "application/yaml",
			contains:    "openapi: 3.0.3",
		},
		{
			name:        "swagger ui",
			path:        "/swagger",
			contentType: "text/html",
			contains:    "SwaggerUIBundle",
		},
		{
			name:        "swagger ui with trailing slash",
			path:        "/swagger/",
			contentType: "text/html",
			contains:    "SwaggerUIBundle",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			recorder := httptest.NewRecorder()
			mux.ServeHTTP(recorder, httptest.NewRequest(http.MethodGet, tt.path, nil))
			if recorder.Code != http.StatusOK {
				t.Fatalf("status = %d, want 200", recorder.Code)
			}
			if contentType := recorder.Header().Get("Content-Type"); !strings.HasPrefix(contentType, tt.contentType) {
				t.Fatalf("content type = %q, want prefix %q", contentType, tt.contentType)
			}
			if !strings.Contains(recorder.Body.String(), tt.contains) {
				t.Fatalf("body does not contain %q", tt.contains)
			}
		})
	}
}

func TestSwaggerUIUsesReachableCDN(t *testing.T) {
	mux := http.NewServeMux()
	registerDocsRoutes(mux)
	recorder := httptest.NewRecorder()
	mux.ServeHTTP(recorder, httptest.NewRequest(http.MethodGet, "/swagger", nil))
	body := recorder.Body.String()
	if !strings.Contains(body, "cdn.jsdelivr.net/npm/swagger-ui-dist@5") {
		t.Fatal("Swagger UI must use the reachable jsDelivr asset host")
	}
	if !strings.Contains(body, "swagger-ui-standalone-preset.js") {
		t.Fatal("Swagger UI must load the standalone preset before using StandaloneLayout")
	}
	if !strings.Contains(body, "presets: [SwaggerUIBundle.presets.apis, SwaggerUIStandalonePreset]") {
		t.Fatal("Swagger UI must pass the standalone preset global to the presets list")
	}
	if strings.Contains(body, "SwaggerUIBundle.SwaggerUIStandalonePreset") {
		t.Fatal("SwaggerUIStandalonePreset is not a property of SwaggerUIBundle")
	}
	if strings.Contains(body, "unpkg.com/swagger-ui-dist") {
		t.Fatal("Swagger UI must not depend on the timed-out unpkg asset host")
	}
}

func TestDocumentationRoutesDoNotChangeBusinessRoutes(t *testing.T) {
	mux := http.NewServeMux()
	registerDocsRoutes(mux)
	recorder := httptest.NewRecorder()
	mux.ServeHTTP(recorder, httptest.NewRequest(http.MethodGet, "/api/v1/videos", nil))
	if recorder.Code != http.StatusNotFound {
		t.Fatalf("business route unexpectedly registered by docs helper: status = %d", recorder.Code)
	}
}

func TestOpenAPIDocumentsScraperRoutes(t *testing.T) {
	mux := http.NewServeMux()
	registerDocsRoutes(mux)
	recorder := httptest.NewRecorder()
	mux.ServeHTTP(recorder, httptest.NewRequest(http.MethodGet, "/openapi.yaml", nil))
	body := recorder.Body.String()
	for _, path := range []string{"/api/v1/admin/scraper/run:", "/api/v1/admin/scraper/status:", "ScraperJob:"} {
		if !strings.Contains(body, path) {
			t.Fatalf("OpenAPI document does not contain %q", path)
		}
	}
}
