package main

import (
	"context"
	"encoding/json"
	"log"
	"os"

	"creatorhub/api/internal/config"
	"creatorhub/api/internal/database"
	"creatorhub/api/internal/homefeed"
)

func main() {
	cfg, err := config.Load()
	if err != nil {
		log.Fatal(err)
	}
	db, err := database.OpenMySQL(context.Background(), cfg.Database)
	if err != nil {
		log.Fatal(err)
	}
	defer db.Close()

	posts, err := homefeed.NewProductSchoolFetcher(nil, os.Getenv("BRIGHTDATA_API_KEY"), os.Getenv("BRIGHTDATA_UNLOCKER_ZONE")).Fetch(context.Background())
	if err != nil {
		log.Fatal(err)
	}
	repository := homefeed.NewRepository(db)
	for _, post := range posts {
		if err := repository.Upsert(context.Background(), post); err != nil {
			log.Fatal(err)
		}
	}
	if err := json.NewEncoder(os.Stdout).Encode(map[string]int{"imported": len(posts)}); err != nil {
		log.Fatal(err)
	}
}
