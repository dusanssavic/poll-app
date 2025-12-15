package service

import (
	"context"
	"errors"

	"poll-app/ent"

	"github.com/google/uuid"
)

// PollService defines poll-related business logic
type PollService interface {
	CreatePoll(ctx context.Context, title, description string, options []string, ownerID uuid.UUID) (*ent.Poll, error)
	GetPollByID(ctx context.Context, id uuid.UUID) (*ent.Poll, error)
	ListPolls(ctx context.Context) ([]*ent.Poll, error)
	UpdatePoll(ctx context.Context, pollID, ownerID uuid.UUID, title, description string, options []string) (*ent.Poll, error)
	DeletePoll(ctx context.Context, pollID, ownerID uuid.UUID) error
	IsPollOwner(ctx context.Context, pollID, userID uuid.UUID) (bool, error)
}

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
	// Permission check: Only poll owner can update the poll
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

	// If options are being updated, identify and clean up votes for removed options
	if len(options) > 0 {
		// Get current poll to compare options
		currentPoll, err := s.storage.GetPollByID(ctx, pollID)
		if err != nil {
			return nil, err
		}

		// Find removed options
		oldOptionsMap := make(map[string]bool)
		for _, opt := range currentPoll.Options {
			oldOptionsMap[opt] = true
		}

		var removedOptions []string
		for _, oldOpt := range currentPoll.Options {
			found := false
			for _, newOpt := range options {
				if oldOpt == newOpt {
					found = true
					break
				}
			}
			if !found {
				removedOptions = append(removedOptions, oldOpt)
			}
		}

		// Delete votes for removed options
		if len(removedOptions) > 0 {
			if err := s.storage.DeleteVotesByPollAndOptions(ctx, pollID, removedOptions); err != nil {
				return nil, err
			}
		}
	}

	return s.storage.UpdatePoll(ctx, pollID, title, description, options)
}

func (s *service) DeletePoll(ctx context.Context, pollID, ownerID uuid.UUID) error {
	// Permission check: Only poll owner can delete the poll
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
