package main

import (
	"net/http"

	apidocs "creatorhub/api/docs"
)

func registerDocsRoutes(mux *http.ServeMux) {
	apidocs.Register(mux)
}
