package docs

import (
	"embed"
	"net/http"
)

//go:embed openapi.yaml swagger.html
var files embed.FS

// Register adds the read-only OpenAPI and Swagger UI endpoints to mux.
func Register(mux *http.ServeMux) {
	mux.HandleFunc("GET /openapi.yaml", func(w http.ResponseWriter, _ *http.Request) {
		content, err := files.ReadFile("openapi.yaml")
		if err != nil {
			http.Error(w, "OpenAPI document unavailable", http.StatusInternalServerError)
			return
		}
		w.Header().Set("Content-Type", "application/yaml; charset=utf-8")
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write(content)
	})
	swaggerHandler := func(w http.ResponseWriter, _ *http.Request) {
		content, err := files.ReadFile("swagger.html")
		if err != nil {
			http.Error(w, "Swagger UI unavailable", http.StatusInternalServerError)
			return
		}
		w.Header().Set("Content-Type", "text/html; charset=utf-8")
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write(content)
	}
	mux.HandleFunc("GET /swagger", swaggerHandler)
	mux.HandleFunc("GET /swagger/", swaggerHandler)
}
