package service

import (
	"context"
	"errors"
	"fmt"

	"poll-app/ent"

	"github.com/google/uuid"
	"golang.org/x/crypto/bcrypt"
)

// UserService defines user-related business logic
type UserService interface {
	CreateUser(ctx context.Context, email, username, password string) (*ent.User, error)
	Login(ctx context.Context, email, password string) (*ent.User, error)
	GetUserByID(ctx context.Context, id uuid.UUID) (*ent.User, error)
}

func (s *service) CreateUser(ctx context.Context, email, username, password string) (*ent.User, error) {
	// Validate inputs
	if email == "" || username == "" || password == "" {
		return nil, errors.New("email, username, and password are required")
	}

	// Check if user already exists
	if _, err := s.storage.GetUserByEmail(ctx, email); err == nil {
		return nil, errors.New("user with this email already exists")
	}

	if _, err := s.storage.GetUserByUsername(ctx, username); err == nil {
		return nil, errors.New("user with this username already exists")
	}

	// Hash password
	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	if err != nil {
		return nil, fmt.Errorf("failed to hash password: %w", err)
	}

	// Create user
	return s.storage.CreateUser(ctx, email, username, string(hashedPassword))
}

func (s *service) Login(ctx context.Context, email, password string) (*ent.User, error) {
	if email == "" || password == "" {
		return nil, errors.New("email and password are required")
	}

	user, err := s.storage.GetUserByEmail(ctx, email)
	if err != nil {
		return nil, errors.New("invalid email or password")
	}

	// Verify password
	if err := bcrypt.CompareHashAndPassword([]byte(user.Password), []byte(password)); err != nil {
		return nil, errors.New("invalid email or password")
	}

	return user, nil
}

func (s *service) GetUserByID(ctx context.Context, id uuid.UUID) (*ent.User, error) {
	return s.storage.GetUserByID(ctx, id)
}
