package service

import (
	"context"
	"errors"
	"fmt"

	"poll-app/ent"
	"poll-app/storage"

	"github.com/google/uuid"
	"golang.org/x/crypto/bcrypt"
)

// Service defines the interface for business logic operations
type Service interface {
	UserService
	PollService
	VoteService
}

// UserService defines user-related business logic
type UserService interface {
	CreateUser(ctx context.Context, email, username, password string) (*ent.User, error)
	Login(ctx context.Context, email, password string) (*ent.User, error)
	GetUserByID(ctx context.Context, id uuid.UUID) (*ent.User, error)
}

// PollService defines poll-related business logic
type PollService interface {
	CreatePoll(ctx context.Context, title, description string, options []string, ownerID uuid.UUID) (*ent.Poll, error)
	GetPollByID(ctx context.Context, id uuid.UUID) (*ent.Poll, error)
	ListPolls(ctx context.Context) ([]*ent.Poll, error)
	UpdatePoll(ctx context.Context, pollID, ownerID uuid.UUID, title, description string, options []string) (*ent.Poll, error)
	DeletePoll(ctx context.Context, pollID, ownerID uuid.UUID) error
	IsPollOwner(ctx context.Context, pollID, userID uuid.UUID) (bool, error)
}

// VoteService defines vote-related business logic
type VoteService interface {
	VoteOnPoll(ctx context.Context, userID, pollID uuid.UUID, option string) (*ent.Vote, error)
	GetVoteCounts(ctx context.Context, pollID uuid.UUID) (map[string]int, error)
	GetVotersByOption(ctx context.Context, pollID uuid.UUID, option string) ([]*ent.User, error)
}

// service implements the Service interface
type service struct {
	storage storage.Storage
}

// NewService creates a new service instance
func NewService(storage storage.Storage) Service {
	return &service{storage: storage}
}

// UserService implementation

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

// PollService implementation

func (s *service) CreatePoll(ctx context.Context, title, description string, options []string, ownerID uuid.UUID) (*ent.Poll, error) {
	if title == "" {
		return nil, errors.New("title is required")
	}

	if len(options) < 2 {
		return nil, errors.New("poll must have at least 2 options")
	}

	// Validate owner exists
	if _, err := s.storage.GetUserByID(ctx, ownerID); err != nil {
		return nil, errors.New("owner not found")
	}

	return s.storage.CreatePoll(ctx, title, description, options, ownerID)
}

func (s *service) GetPollByID(ctx context.Context, id uuid.UUID) (*ent.Poll, error) {
	return s.storage.GetPollByID(ctx, id)
}

func (s *service) ListPolls(ctx context.Context) ([]*ent.Poll, error) {
	return s.storage.ListPolls(ctx)
}

func (s *service) UpdatePoll(ctx context.Context, pollID, ownerID uuid.UUID, title, description string, options []string) (*ent.Poll, error) {
	// Check ownership
	isOwner, err := s.IsPollOwner(ctx, pollID, ownerID)
	if err != nil {
		return nil, err
	}
	if !isOwner {
		return nil, errors.New("only poll owner can update the poll")
	}

	// Validate options if provided
	if len(options) > 0 && len(options) < 2 {
		return nil, errors.New("poll must have at least 2 options")
	}

	return s.storage.UpdatePoll(ctx, pollID, title, description, options)
}

func (s *service) DeletePoll(ctx context.Context, pollID, ownerID uuid.UUID) error {
	// Check ownership
	isOwner, err := s.IsPollOwner(ctx, pollID, ownerID)
	if err != nil {
		return err
	}
	if !isOwner {
		return errors.New("only poll owner can delete the poll")
	}

	return s.storage.DeletePoll(ctx, pollID)
}

func (s *service) IsPollOwner(ctx context.Context, pollID, userID uuid.UUID) (bool, error) {
	poll, err := s.storage.GetPollByID(ctx, pollID)
	if err != nil {
		return false, err
	}

	return poll.OwnerID == userID, nil
}

// VoteService implementation

func (s *service) VoteOnPoll(ctx context.Context, userID, pollID uuid.UUID, option string) (*ent.Vote, error) {
	if option == "" {
		return nil, errors.New("option is required")
	}

	// Get poll to validate option exists
	poll, err := s.storage.GetPollByID(ctx, pollID)
	if err != nil {
		return nil, errors.New("poll not found")
	}

	// Validate option is in poll options
	validOption := false
	for _, opt := range poll.Options {
		if opt == option {
			validOption = true
			break
		}
	}
	if !validOption {
		return nil, errors.New("invalid option for this poll")
	}

	// Check if user already voted
	existingVote, err := s.storage.GetVoteByUserAndPoll(ctx, userID, pollID)
	if err == nil && existingVote != nil {
		return nil, errors.New("user has already voted on this poll")
	}

	// Create vote
	return s.storage.CreateVote(ctx, userID, pollID, option)
}

func (s *service) GetVoteCounts(ctx context.Context, pollID uuid.UUID) (map[string]int, error) {
	return s.storage.GetVoteCountsByPoll(ctx, pollID)
}

func (s *service) GetVotersByOption(ctx context.Context, pollID uuid.UUID, option string) ([]*ent.User, error) {
	votes, err := s.storage.GetVotesByPollAndOption(ctx, pollID, option)
	if err != nil {
		return nil, err
	}

	users := make([]*ent.User, 0, len(votes))
	for _, vote := range votes {
		user, err := vote.QueryUser().Only(ctx)
		if err != nil {
			continue
		}
		users = append(users, user)
	}

	return users, nil
}
