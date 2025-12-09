# Poll App Backend

Backend service for the poll application built with Go.

## Project Structure

```
backend/
├── main.go              # Entry point with cobra CLI
├── cmd/
│   └── server/          # Server command implementation
├── controller/          # HTTP handlers
├── service/             # Business logic
├── storage/             # Data access layer
└── bin/                 # Build output directory
```

## Development

### Run the server
```bash
go run main.go server
```

### Run with custom port
```bash
go run main.go server --port 3000
```

### Run tests
```bash
go test ./...
```

### Build binary
```bash
go build -o bin/poll-app main.go
```

## Dependencies

- **cobra**: CLI framework
- **httprouter**: HTTP router
- **ent**: Database ORM
- **mockery**: Mock generation tool

## Architecture

The backend follows an N-layered architecture:

1. **Controller Layer**: Handles HTTP requests/responses
2. **Service Layer**: Contains business logic
3. **Storage Layer**: Handles database operations

Each layer uses interfaces to enable testing and mock generation.

