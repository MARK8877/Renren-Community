package main

import (
	"context"
	"fmt"
	"log"
	"os"
	"strings"

	"creatorhub/api/internal/config"
	"creatorhub/api/internal/database"
	"golang.org/x/crypto/bcrypt"
)

func main() {
	if len(os.Args) != 4 {
		log.Fatal("usage: go run ./cmd/createadmin <email-or-phone> <password> <nickname>")
	}
	identifier, password, nickname := strings.TrimSpace(strings.ToLower(os.Args[1])), os.Args[2], strings.TrimSpace(os.Args[3])
	if len(password) < 8 || identifier == "" || nickname == "" {
		log.Fatal("identifier and nickname are required; password must contain at least 8 characters")
	}
	cfg, err := config.Load()
	if err != nil {
		log.Fatal(err)
	}
	db, err := database.OpenMySQL(context.Background(), cfg.Database)
	if err != nil {
		log.Fatal(err)
	}
	defer db.Close()
	hash, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	if err != nil {
		log.Fatal(err)
	}
	email, phone := "", identifier
	if strings.Contains(identifier, "@") {
		email, phone = identifier, ""
	}
	_, err = db.Exec(`INSERT INTO users(email,phone,password_hash,nickname,role) VALUES(NULLIF(?,''),NULLIF(?,''),?,?,'admin')`, email, phone, string(hash), nickname)
	if err != nil {
		log.Fatal(err)
	}
	fmt.Println("administrator created")
}
