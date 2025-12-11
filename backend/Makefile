.PHONY: test dev clean build generate fmt lint help

# Docker Compose file for development
COMPOSE_FILE := ../docker-compose.dev.yml

# Default target
.DEFAULT_GOAL := help

## test: Run Go tests (automatically starts containers if needed)
test:
	@echo "Setting up database containers for tests..."
	@docker-compose -f $(COMPOSE_FILE) up -d postgres redis
	@echo "Waiting for containers to be healthy..."
	@for i in $$(seq 1 30); do \
		if docker-compose -f $(COMPOSE_FILE) ps | grep -q "healthy"; then \
			break; \
		fi; \
		sleep 1; \
	done
	@echo "Running tests..."
	@POSTGRES_HOST=localhost \
	 POSTGRES_PORT=5432 \
	 POSTGRES_USER=pollapp \
	 POSTGRES_PASSWORD=pollapp \
	 POSTGRES_DB=pollapp \
	 POSTGRES_SSLMODE=disable \
	 REDIS_HOST=localhost \
	 REDIS_PORT=6379 \
	 go test ./...

## dev: Start all containers (postgres, redis, backend)
dev:
	@echo "Starting all containers..."
	@docker-compose -f $(COMPOSE_FILE) up -d
	@echo "Waiting for containers to be healthy..."
	@for i in $$(seq 1 30); do \
		if docker-compose -f $(COMPOSE_FILE) ps | grep -q "healthy"; then \
			break; \
		fi; \
		sleep 1; \
	done
	@echo "All services are running!"
	@echo "Backend API available at http://localhost:8080"
	@echo "Use 'docker-compose -f $(COMPOSE_FILE) logs -f backend' to view backend logs"
	@echo "Use 'make clean' to stop all containers"

## clean: Stop and remove containers
clean:
	@echo "Stopping and removing containers..."
	@docker-compose -f $(COMPOSE_FILE) down
	@echo "Containers stopped and removed."

## build: Build the Go binary
build:
	@echo "Building binary..."
	@go build -o bin/poll-app main.go
	@echo "Binary built: bin/poll-app"

## generate: Generate ent code
generate:
	@echo "Generating ent code..."
	@go generate ./ent
	@echo "Ent code generated."

## fmt: Format Go code with gofmt
fmt:
	@echo "Formatting code..."
	@gofmt -w .
	@echo "Code formatted."

## lint: Run gofmt check
lint:
	@echo "Checking code formatting..."
	@if [ $$(gofmt -l . | wc -l) -ne 0 ]; then \
		echo "Code is not formatted. Run 'make fmt' to fix."; \
		gofmt -l .; \
		exit 1; \
	fi
	@echo "Code is properly formatted."

## help: Display available targets with descriptions
help:
	@echo "Available targets:"
	@echo ""
	@echo "  make test      - Run Go tests (automatically starts containers if needed)"
	@echo "  make dev       - Start all containers (postgres, redis, backend)"
	@echo "  make clean     - Stop and remove containers"
	@echo "  make build     - Build the Go binary"
	@echo "  make generate  - Generate ent code"
	@echo "  make fmt       - Format Go code with gofmt"
	@echo "  make lint      - Run gofmt check"
	@echo "  make help      - Display this help message"
	@echo ""

