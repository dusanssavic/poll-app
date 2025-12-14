package service

import (
	"context"
	"errors"

	"poll-app/ent"

	"github.com/google/uuid"
)

// VoteService defines vote-related business logic
type VoteService interface {
	VoteOnPoll(ctx context.Context, userID, pollID uuid.UUID, option string) (*ent.Vote, error)
	GetVoteCounts(ctx context.Context, pollID uuid.UUID) (map[string]int, error)
	GetVotersByOption(ctx context.Context, pollID uuid.UUID, option string) ([]*ent.User, error)
	DeleteVote(ctx context.Context, userID, pollID uuid.UUID) error
}

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
		// Check if existing vote is for a valid option
		validExistingOption := false
		for _, opt := range poll.Options {
			if opt == existingVote.Option {
				validExistingOption = true
				break
			}
		}
		// If existing vote is for an invalid/deleted option, delete it and allow re-voting
		if !validExistingOption {
			if err := s.storage.DeleteVoteByUserAndPoll(ctx, userID, pollID); err != nil {
				return nil, err
			}
		} else {
			return nil, errors.New("user has already voted on this poll")
		}
	}

	// Create vote
	return s.storage.CreateVote(ctx, userID, pollID, option)
}

func (s *service) GetVoteCounts(ctx context.Context, pollID uuid.UUID) (map[string]int, error) {
	// Validate poll exists
	_, err := s.storage.GetPollByID(ctx, pollID)
	if err != nil {
		return nil, errors.New("poll not found")
	}

	return s.storage.GetVoteCountsByPoll(ctx, pollID)
}

func (s *service) GetVotersByOption(ctx context.Context, pollID uuid.UUID, option string) ([]*ent.User, error) {
	// Validate poll exists
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
		return nil, errors.New("option not found")
	}

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

func (s *service) DeleteVote(ctx context.Context, userID, pollID uuid.UUID) error {
	// Validate poll exists
	_, err := s.storage.GetPollByID(ctx, pollID)
	if err != nil {
		return errors.New("poll not found")
	}

	// Check if vote exists
	existingVote, err := s.storage.GetVoteByUserAndPoll(ctx, userID, pollID)
	if err != nil {
		return errors.New("vote not found")
	}

	// User can only delete their own vote
	if existingVote.UserID != userID {
		return errors.New("unauthorized: can only delete your own vote")
	}

	return s.storage.DeleteVoteByUserAndPoll(ctx, userID, pollID)
}
