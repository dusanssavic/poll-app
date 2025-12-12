package service

import "poll-app/storage"

// Service defines the interface for business logic operations
type Service interface {
	UserService
	PollService
	VoteService
}

// service implements the Service interface
type service struct {
	storage storage.Storage
}

// NewService creates a new service instance
func NewService(storage storage.Storage) Service {
	return &service{storage: storage}
}
