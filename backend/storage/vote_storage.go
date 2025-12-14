package storage

import (
	"context"

	"poll-app/ent"
	"poll-app/ent/vote"

	"github.com/google/uuid"
)

// VoteStorage defines vote-related database operations
type VoteStorage interface {
	CreateVote(ctx context.Context, userID, pollID uuid.UUID, option string) (*ent.Vote, error)
	GetVoteByUserAndPoll(ctx context.Context, userID, pollID uuid.UUID) (*ent.Vote, error)
	GetVotesByPoll(ctx context.Context, pollID uuid.UUID) ([]*ent.Vote, error)
	GetVotesByPollAndOption(ctx context.Context, pollID uuid.UUID, option string) ([]*ent.Vote, error)
	GetVoteCountsByPoll(ctx context.Context, pollID uuid.UUID) (map[string]int, error)
	DeleteVoteByUserAndPoll(ctx context.Context, userID, pollID uuid.UUID) error
	DeleteVotesByPollAndOptions(ctx context.Context, pollID uuid.UUID, options []string) error
}

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

func (s *storage) DeleteVoteByUserAndPoll(ctx context.Context, userID, pollID uuid.UUID) error {
	_, err := s.client.Vote.
		Delete().
		Where(
			vote.UserID(userID),
			vote.PollID(pollID),
		).
		Exec(ctx)
	return err
}

func (s *storage) DeleteVotesByPollAndOptions(ctx context.Context, pollID uuid.UUID, options []string) error {
	if len(options) == 0 {
		return nil
	}

	_, err := s.client.Vote.
		Delete().
		Where(
			vote.PollID(pollID),
			vote.OptionIn(options...),
		).
		Exec(ctx)
	return err
}
