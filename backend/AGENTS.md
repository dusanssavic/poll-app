# Poll App Backend

Backend service for the poll application built with Go.

## Project Structure

```
backend/
├── main.go              # Entry point with cobra CLI
├── cmd/
│   └── server/          # Server command implementation
├── controller/          # HTTP handlers
│   ├── user_controller.go
│   ├── poll_controller.go
│   └── vote_controller.go
├── service/             # Business logic
│   └── service.go
├── storage/             # Data access layer
│   ├── storage.go
│   └── db.go
├── auth/                # Authentication and authorization
│   ├── jwt.go           # JWT token management
│   ├── middleware.go    # Auth middleware
│   └── redis.go         # Redis client for token storage
├── ent/                 # Generated ent ORM code
│   └── schema/          # Database schema definitions
└── bin/                 # Build output directory
```

## Development

### Prerequisites

- PostgreSQL 16+ (or use Docker Compose)
- Redis 7+ (or use Docker Compose)
- Go 1.25.5+

### Environment Variables

The following environment variables can be set (defaults shown):

```bash
# PostgreSQL
POSTGRES_HOST=localhost
POSTGRES_PORT=5432
POSTGRES_USER=pollapp
POSTGRES_PASSWORD=pollapp
POSTGRES_DB=pollapp
POSTGRES_SSLMODE=disable

# Redis
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_PASSWORD=

# JWT
JWT_SECRET_KEY=default-secret-key-change-in-production
```

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

### Generate ent code
```bash
go generate ./ent
```

## Dependencies

- **cobra**: CLI framework
- **httprouter**: HTTP router
- **entgo.io/ent**: Database ORM
- **github.com/lib/pq**: PostgreSQL driver
- **github.com/golang-jwt/jwt/v5**: JWT token handling
- **github.com/redis/go-redis/v9**: Redis client
- **golang.org/x/crypto/bcrypt**: Password hashing
- **github.com/google/uuid**: UUID generation
- **mockery**: Mock generation tool (for testing)

## Architecture

The backend follows an N-layered architecture:

1. **Controller Layer**: Handles HTTP requests/responses
   - `UserController`: User registration, login, token refresh
   - `PollController`: Poll CRUD operations
   - `VoteController`: Voting and vote retrieval

2. **Service Layer**: Contains business logic
   - User authentication and validation
   - Poll ownership checks
   - Vote validation (one vote per user per poll)

3. **Storage Layer**: Handles database operations
   - Uses ent ORM for database access
   - PostgreSQL for entity storage
   - Redis for JWT refresh token caching

4. **Auth Layer**: Authentication and authorization
   - JWT token generation and validation
   - Auth middleware for protected routes
   - Redis integration for token management

Each layer uses interfaces to enable testing and mock generation.

## API Documentation

The API is fully documented using OpenAPI 3.0 specification. See `api/openapi.yaml` for complete documentation.

### Quick Reference

**User Endpoints (Public)**
- `POST /api/users` - Create new user
- `POST /api/users/login` - User login
- `POST /api/users/refresh` - Refresh access token

**Poll Endpoints**
- `GET /api/polls` - List all polls (Public)
- `GET /api/polls/:id` - Get poll details (Public)
- `POST /api/polls` - Create new poll (Protected)
- `PUT /api/polls/:id` - Update poll (Protected, owner only)
- `DELETE /api/polls/:id` - Delete poll (Protected, owner only)

**Vote Endpoints**
- `POST /api/polls/:id/vote` - Vote on a poll (Protected)
- `GET /api/polls/:id/votes` - Get vote counts (Public)
- `GET /api/polls/:id/votes/:option` - Get voters for specific option (Public)

**Health Check**
- `GET /health` - Health check endpoint

### Generating Frontend Client

The OpenAPI spec can be used to generate TypeScript clients for the frontend. See `api/README.md` for instructions.

## Database Schema

The application uses three main entities:

- **User**: Stores user credentials and profile information
- **Poll**: Stores poll information with title, description, and options
- **Vote**: Stores individual votes with a unique constraint on (user_id, poll_id)

The schema is automatically migrated on server startup.

