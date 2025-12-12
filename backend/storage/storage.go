package storage

import (
	"context"
	"time"

	"poll-app/ent"
	"poll-app/ent/poll"
	"poll-app/ent/user"
	"poll-app/ent/vote"

	"github.com/google/uuid"
)

// Storage defines the interface for data access operations
type Storage interface {
	UserStorage
	PollStorage
	VoteStorage
	Close() error
}

// UserStorage defines user-related database operations
type UserStorage interface {
	CreateUser(ctx context.Context, email, username, hashedPassword string) (*ent.User, error)
	GetUserByID(ctx context.Context, id uuid.UUID) (*ent.User, error)
	GetUserByEmail(ctx context.Context, email string) (*ent.User, error)
	GetUserByUsername(ctx context.Context, username string) (*ent.User, error)
}

// PollStorage defines poll-related database operations
type PollStorage interface {
	CreatePoll(ctx context.Context, title, description string, options []string, ownerID uuid.UUID) (*ent.Poll, error)
	GetPollByID(ctx context.Context, id uuid.UUID) (*ent.Poll, error)
	ListPolls(ctx context.Context) ([]*ent.Poll, error)
	UpdatePoll(ctx context.Context, id uuid.UUID, title, description string, options []string) (*ent.Poll, error)
	DeletePoll(ctx context.Context, id uuid.UUID) error
	GetPollsByOwner(ctx context.Context, ownerID uuid.UUID) ([]*ent.Poll, error)
}

// VoteStorage defines vote-related database operations
type VoteStorage interface {
	CreateVote(ctx context.Context, userID, pollID uuid.UUID, option string) (*ent.Vote, error)
	GetVoteByUserAndPoll(ctx context.Context, userID, pollID uuid.UUID) (*ent.Vote, error)
	GetVotesByPoll(ctx context.Context, pollID uuid.UUID) ([]*ent.Vote, error)
	GetVotesByPollAndOption(ctx context.Context, pollID uuid.UUID, option string) ([]*ent.Vote, error)
	GetVoteCountsByPoll(ctx context.Context, pollID uuid.UUID) (map[string]int, error)
}

// storage implements the Storage interface
type storage struct {
	client *ent.Client
}

// NewStorage creates a new storage instance
func NewStorage(client *ent.Client) Storage {
	return &storage{client: client}
}

// Close closes the database connection
func (s *storage) Close() error {
	return s.client.Close()
}

// UserStorage implementation

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

// PollStorage implementation

func (s *storage) CreatePoll(ctx context.Context, title, description string, options []string, ownerID uuid.UUID) (*ent.Poll, error) {
	return s.client.Poll.
		Create().
		SetTitle(title).
		SetDescription(description).
		SetOptions(options).
		SetOwnerID(ownerID).
		Save(ctx)
}

func (s *storage) GetPollByID(ctx context.Context, id uuid.UUID) (*ent.Poll, error) {
	return s.client.Poll.
		Query().
		Where(poll.ID(id)).
		WithOwner().
		WithVotes(func(vq *ent.VoteQuery) {
			vq.WithUser()
		}).
		Only(ctx)
}

func (s *storage) ListPolls(ctx context.Context) ([]*ent.Poll, error) {
	return s.client.Poll.
		Query().
		WithOwner().
		Order(ent.Desc(poll.FieldCreatedAt)).
		All(ctx)
}

func (s *storage) UpdatePoll(ctx context.Context, id uuid.UUID, title, description string, options []string) (*ent.Poll, error) {
	update := s.client.Poll.
		UpdateOneID(id).
		SetUpdatedAt(time.Now())

	if title != "" {
		update = update.SetTitle(title)
	}
	if description != "" {
		update = update.SetDescription(description)
	}
	if len(options) > 0 {
		update = update.SetOptions(options)
	}

	return update.Save(ctx)
}

func (s *storage) DeletePoll(ctx context.Context, id uuid.UUID) error {
	return s.client.Poll.
		DeleteOneID(id).
		Exec(ctx)
}

func (s *storage) GetPollsByOwner(ctx context.Context, ownerID uuid.UUID) ([]*ent.Poll, error) {
	return s.client.Poll.
		Query().
		Where(poll.OwnerID(ownerID)).
		WithOwner().
		Order(ent.Desc(poll.FieldCreatedAt)).
		All(ctx)
}

// VoteStorage implementation

func (s *storage) CreateVote(ctx context.Context, userID, pollID uuid.UUID, option string) (*ent.Vote, error) {
	return s.client.Vote.
		Create().
		SetUserID(userID).
		SetPollID(pollID).
		SetOption(option).
		Save(ctx)
}

func (s *storage) GetVoteByUserAndPoll(ctx context.Context, userID, pollID uuid.UUID) (*ent.Vote, error) {
	return s.client.Vote.
		Query().
		Where(
			vote.UserID(userID),
			vote.PollID(pollID),
		).
		Only(ctx)
}

func (s *storage) GetVotesByPoll(ctx context.Context, pollID uuid.UUID) ([]*ent.Vote, error) {
	return s.client.Vote.
		Query().
		Where(vote.PollID(pollID)).
		WithUser().
		All(ctx)
}

func (s *storage) GetVotesByPollAndOption(ctx context.Context, pollID uuid.UUID, option string) ([]*ent.Vote, error) {
	return s.client.Vote.
		Query().
		Where(
			vote.PollID(pollID),
			vote.Option(option),
		).
		WithUser().
		All(ctx)
}

func (s *storage) GetVoteCountsByPoll(ctx context.Context, pollID uuid.UUID) (map[string]int, error) {
	votes, err := s.client.Vote.
		Query().
		Where(vote.PollID(pollID)).
		All(ctx)
	if err != nil {
		return nil, err
	}

	counts := make(map[string]int)
	for _, v := range votes {
		counts[v.Option]++
	}

	return counts, nil
}
