package storage

import (
	"context"
	"time"

	"poll-app/ent"
	"poll-app/ent/poll"

	"github.com/google/uuid"
)

// PollStorage defines poll-related database operations
type PollStorage interface {
	CreatePoll(ctx context.Context, title, description string, options []string, ownerID uuid.UUID) (*ent.Poll, error)
	GetPollByID(ctx context.Context, id uuid.UUID) (*ent.Poll, error)
	ListPolls(ctx context.Context) ([]*ent.Poll, error)
	UpdatePoll(ctx context.Context, id uuid.UUID, title, description string, options []string) (*ent.Poll, error)
	DeletePoll(ctx context.Context, id uuid.UUID) error
	GetPollsByOwner(ctx context.Context, ownerID uuid.UUID) ([]*ent.Poll, error)
}

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

