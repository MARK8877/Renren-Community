package config

import (
	"fmt"
	"os"
	"strconv"
	"time"
)

type Config struct {
	AppPort  string
	Database DatabaseConfig
	Auth     AuthConfig
	Scraper  ScraperConfig
}

type AuthConfig struct {
	TokenSecret []byte
	TokenTTL    time.Duration
}

type DatabaseConfig struct {
	Host            string
	Port            int
	Name            string
	User            string
	Password        string
	MaxOpenConns    int
	MaxIdleConns    int
	ConnMaxLifetime time.Duration
}

type ScraperConfig struct {
	Interval   time.Duration
	Timeout    time.Duration
	PythonBin  string
	ScriptPath string
}

func Load() (Config, error) {
	databasePort, err := envInt("MYSQL_PORT", 3306)
	if err != nil {
		return Config{}, err
	}
	maxOpenConns, err := envInt("MYSQL_MAX_OPEN_CONNS", 25)
	if err != nil {
		return Config{}, err
	}
	maxIdleConns, err := envInt("MYSQL_MAX_IDLE_CONNS", 10)
	if err != nil {
		return Config{}, err
	}
	lifetimeMinutes, err := envInt("MYSQL_CONN_MAX_LIFETIME_MINUTES", 5)
	if err != nil {
		return Config{}, err
	}
	tokenTTLHours, err := envInt("AUTH_TOKEN_TTL_HOURS", 168)
	if err != nil {
		return Config{}, err
	}
	interval, err := envDuration("SCRAPER_INTERVAL", 4*time.Hour)
	if err != nil {
		return Config{}, err
	}
	timeout, err := envDuration("SCRAPER_TIMEOUT", 15*time.Minute)
	if err != nil {
		return Config{}, err
	}
	if interval <= 0 || timeout <= 0 {
		return Config{}, fmt.Errorf("SCRAPER_INTERVAL and SCRAPER_TIMEOUT must be positive")
	}

	config := Config{
		AppPort: envString("APP_PORT", "18080"),
		Database: DatabaseConfig{
			Host:            envString("MYSQL_HOST", "127.0.0.1"),
			Port:            databasePort,
			Name:            os.Getenv("MYSQL_DATABASE"),
			User:            os.Getenv("MYSQL_USER"),
			Password:        os.Getenv("MYSQL_PASSWORD"),
			MaxOpenConns:    maxOpenConns,
			MaxIdleConns:    maxIdleConns,
			ConnMaxLifetime: time.Duration(lifetimeMinutes) * time.Minute,
		},
		Auth: AuthConfig{
			TokenSecret: []byte(os.Getenv("AUTH_TOKEN_SECRET")),
			TokenTTL:    time.Duration(tokenTTLHours) * time.Hour,
		},
		Scraper: ScraperConfig{
			Interval:   interval,
			Timeout:    timeout,
			PythonBin:  envString("SCRAPER_PYTHON_BIN", "scraper/.venv/bin/python"),
			ScriptPath: envString("SCRAPER_SCRIPT_PATH", "scraper/free_video_scraper.py"),
		},
	}

	if config.Database.Name == "" || config.Database.User == "" {
		return Config{}, fmt.Errorf("MYSQL_DATABASE and MYSQL_USER are required")
	}
	if len(config.Auth.TokenSecret) < 32 {
		return Config{}, fmt.Errorf("AUTH_TOKEN_SECRET must contain at least 32 characters")
	}
	return config, nil
}

func envString(key, fallback string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return fallback
}

func envInt(key string, fallback int) (int, error) {
	value := os.Getenv(key)
	if value == "" {
		return fallback, nil
	}
	parsed, err := strconv.Atoi(value)
	if err != nil {
		return 0, fmt.Errorf("%s must be an integer: %w", key, err)
	}
	return parsed, nil
}

func envDuration(key string, fallback time.Duration) (time.Duration, error) {
	value := os.Getenv(key)
	if value == "" {
		return fallback, nil
	}
	parsed, err := time.ParseDuration(value)
	if err != nil {
		return 0, fmt.Errorf("%s must be a duration: %w", key, err)
	}
	return parsed, nil
}
