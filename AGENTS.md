# Repository Guidelines

## Project Overview

This application is being built to practice deployment processes on Nutanix infrastructure. It's a full-stack poll application with authentication, poll management, and voting functionality.

## Product Requirements

### Authentication
- User sign in and sign up functionality
- JWT-based authentication

### Poll Management
- List all polls
- View poll details
- Create new polls with multiple options
- Edit existing polls (owner only)
- Delete polls (owner only)

### Voting Functionality
- Vote on a poll via UI (one vote per poll per user)
- Display vote counts for each option after voting
- Vote counts should be clickable/interactive

### Results Visualization
- Display vote counts for each poll option
- When clicking on a vote count, show all users who selected that option
- Real-time or near-real-time vote count updates

## Technical Requirements

### Frontend
- **Technology**: React with TypeScript
- **Screens**:
    - List Polls screen with icons to show details, and pencil icon if owner
    - Create New Poll screen
    - Edit Poll screen (if owner)
    - Vote on Poll screen (only one vote per Poll)
- **Functionality**:
    - Delete Poll functionality (if owner)

### Backend
- **Technology**: Go (Golang)
- **Frameworks/Libraries**:
    - cobra (CLI framework)
    - httprouter (HTTP router)
    - ent ORM (database ORM)
    - testing - standard lib
    - mockery - to generate mocks from interfaces
- **API Endpoints**:
    - **User APIs**:
        - Create User
        - Login
    - **Poll APIs**:
        - List Polls
        - Show Poll
        - Create Poll
        - Update Poll (description and/or options)
        - Delete Poll
        - Vote on Poll
- **Authentication**:
    - JWT-based authentication
    - JWT token refreshment handling

### Database
- **Technology**:
    - PostgreSQL for entities
    - Redis for JWT caching
- **Schema Design**:
    - Design database schema to model Users, Polls and Votes
    - Create appropriate table(s) in the database
- **Data Requirements**:
    - Poll information (title, description, options, etc.)
    - Vote records (user, poll, option selected, timestamp)
    - User information (for authentication)

## Project Structure

### Backend Structure
- See `backend/AGENTS.md` for detailed backend structure and architecture

### Frontend Structure
- See `frontend/AGENTS.md` for detailed frontend structure and commands

## Commands

### Development

#### Local Development (Full App)
- TODO

#### Frontend Only
- See `frontend/AGENTS.md` for frontend-specific commands

#### Backend Only
- See `backend/AGENTS.md` for backend-specific commands

### Build

#### Full Application
- TODO

#### Frontend Only
- See `frontend/AGENTS.md` for frontend build commands

#### Backend Only
- See `backend/AGENTS.md` for backend build commands

### Docker

#### Build Docker Images
- `docker build -t poll-app-backend -f Dockerfile.backend .` - Build backend image
- `docker build -t poll-app-frontend -f Dockerfile.frontend .` - Build frontend image

#### Run with Docker Compose
- 

#### Run Individual Containers
- TODO

### Testing
- `go test ./...` - Run all Go unit tests

## Coding Style & Naming

### Go
- Format code with `go fmt ./...`
- Keep packages lowercase
- Exported symbols in PascalCase
- Errors with `%w` when wrapping
- Imports: group stdlib/external/local

### TypeScript/React
- 2-space indent
- `PascalCase` for components (`App.tsx`)
- `camelCase` for variables
- Keep JSX files as `.tsx`
- Strict mode enabled
- Keep relative paths stable

## Testing Guidelines

### Go Tests
- Place next to sources as `*_test.go`
- Aim for core logic coverage
- Run with `go test ./...`

### Frontend Tests
- None currently configured
- If adding, prefer Vitest + React Testing Library
- Colocate as `Component.test.tsx`
- Run with `npm test` in `frontend/`

## Commit & PR Guidelines

### Commits
- Use concise, imperative messages
- Conventional Commits style preferred: `feat:`, `fix:`, `chore:`, `docs:`, `refactor:`