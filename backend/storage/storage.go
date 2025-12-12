package storage

import "poll-app/ent"

// Storage defines the interface for data access operations
type Storage interface {
	UserStorage
	PollStorage
	VoteStorage
	Close() error
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
