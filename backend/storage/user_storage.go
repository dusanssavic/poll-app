package storage

import (
	"context"

	"poll-app/ent"
	"poll-app/ent/user"

	"github.com/google/uuid"
)

// UserStorage defines user-related database operations
type UserStorage interface {
	CreateUser(ctx context.Context, email, username, hashedPassword string) (*ent.User, error)
	GetUserByID(ctx context.Context, id uuid.UUID) (*ent.User, error)
	GetUserByEmail(ctx context.Context, email string) (*ent.User, error)
	GetUserByUsername(ctx context.Context, username string) (*ent.User, error)
}

func (s *storage) CreateUser(ctx context.Context, email, username, hashedPassword string) (*ent.User, error) {
	return s.client.User.
		Create().
		SetEmail(email).
		SetUsername(username).
		SetPassword(hashedPassword).
		Save(ctx)
}

func (s *storage) GetUserByID(ctx context.Context, id uuid.UUID) (*ent.User, error) {
	return s.client.User.
		Query().
		Where(user.ID(id)).
		Only(ctx)
}

func (s *storage) GetUserByEmail(ctx context.Context, email string) (*ent.User, error) {
	return s.client.User.
		Query().
		Where(user.Email(email)).
		Only(ctx)
}

func (s *storage) GetUserByUsername(ctx context.Context, username string) (*ent.User, error) {
	return s.client.User.
		Query().
		Where(user.Username(username)).
		Only(ctx)
}

