package storage

import (
	"context"
	"fmt"
	"log"
	"os"
	"time"

	"poll-app/ent"

	"entgo.io/ent/dialect"
	_ "github.com/lib/pq"
)

// NewClient creates a new ent database client
func NewClient() (*ent.Client, error) {
	// Hardcoded database credentials (using default PostgreSQL setup)
	const dbname = "postgres"
	const user = "postgres"
	const password = "postgres"

	// Configurable connection settings
	host := getEnv("POSTGRES_HOST", "localhost")
	port := getEnv("POSTGRES_PORT", "5432")
	sslmode := getEnv("POSTGRES_SSLMODE", "disable")

	dsn := fmt.Sprintf("host=%s port=%s user=%s password=%s dbname=%s sslmode=%s",
		host, port, user, password, dbname, sslmode)

	client, err := ent.Open(dialect.Postgres, dsn)
	if err != nil {
		return nil, fmt.Errorf("failed opening connection to postgres: %w", err)
	}

	// Run the auto migration tool
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	if err := client.Schema.Create(ctx); err != nil {
		return nil, fmt.Errorf("failed creating schema resources: %w", err)
	}

	log.Println("Database connection established and schema migrated")
	return client, nil
}

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}
