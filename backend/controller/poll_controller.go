package controller

import (
	"encoding/json"
	"net/http"

	"poll-app/auth"
	"poll-app/ent"
	"poll-app/service"

	"github.com/google/uuid"
	"github.com/julienschmidt/httprouter"
)

// PollController handles poll-related HTTP requests
type PollController struct {
	service service.PollService
}

// NewPollController creates a new poll controller
func NewPollController(service service.PollService) *PollController {
	return &PollController{service: service}
}

// CreatePollRequest represents the request body for creating a poll
type CreatePollRequest struct {
	Title       string   `json:"title"`
	Description string   `json:"description"`
	Options     []string `json:"options"`
}

// UpdatePollRequest represents the request body for updating a poll
type UpdatePollRequest struct {
	Title       string   `json:"title"`
	Description string   `json:"description"`
	Options     []string `json:"options"`
}

// PollResponse represents a poll in API responses
type PollResponse struct {
	ID          uuid.UUID `json:"id"`
	Title       string    `json:"title"`
	Description string    `json:"description"`
	Options     []string  `json:"options"`
	OwnerID     uuid.UUID `json:"owner_id"`
	CreatedAt   string    `json:"created_at"`
	UpdatedAt   string    `json:"updated_at"`
}

// ListPolls handles GET /api/polls
func (c *PollController) ListPolls(w http.ResponseWriter, r *http.Request, _ httprouter.Params) {
	polls, err := c.service.ListPolls(r.Context())
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	responses := make([]PollResponse, 0, len(polls))
	for _, poll := range polls {
		responses = append(responses, pollToResponse(poll))
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(responses)
}

// GetPoll handles GET /api/polls/:id
func (c *PollController) GetPoll(w http.ResponseWriter, r *http.Request, ps httprouter.Params) {
	id, err := uuid.Parse(ps.ByName("id"))
	if err != nil {
		http.Error(w, "Invalid poll ID", http.StatusBadRequest)
		return
	}

	poll, err := c.service.GetPollByID(r.Context(), id)
	if err != nil {
		http.Error(w, "Poll not found", http.StatusNotFound)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(pollToResponse(poll))
}

// CreatePoll handles POST /api/polls
func (c *PollController) CreatePoll(w http.ResponseWriter, r *http.Request, _ httprouter.Params) {
	userID, ok := auth.GetUserIDFromContext(r.Context())
	if !ok {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}

	var req CreatePollRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid request body", http.StatusBadRequest)
		return
	}

	poll, err := c.service.CreatePoll(r.Context(), req.Title, req.Description, req.Options, userID)
	if err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(pollToResponse(poll))
}

// UpdatePoll handles PUT /api/polls/:id
func (c *PollController) UpdatePoll(w http.ResponseWriter, r *http.Request, ps httprouter.Params) {
	userID, ok := auth.GetUserIDFromContext(r.Context())
	if !ok {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}

	id, err := uuid.Parse(ps.ByName("id"))
	if err != nil {
		http.Error(w, "Invalid poll ID", http.StatusBadRequest)
		return
	}

	var req UpdatePollRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid request body", http.StatusBadRequest)
		return
	}

	poll, err := c.service.UpdatePoll(r.Context(), id, userID, req.Title, req.Description, req.Options)
	if err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(pollToResponse(poll))
}

// DeletePoll handles DELETE /api/polls/:id
func (c *PollController) DeletePoll(w http.ResponseWriter, r *http.Request, ps httprouter.Params) {
	userID, ok := auth.GetUserIDFromContext(r.Context())
	if !ok {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}

	id, err := uuid.Parse(ps.ByName("id"))
	if err != nil {
		http.Error(w, "Invalid poll ID", http.StatusBadRequest)
		return
	}

	if err := c.service.DeletePoll(r.Context(), id, userID); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	w.WriteHeader(http.StatusNoContent)
}

// Helper function to convert ent.Poll to PollResponse
func pollToResponse(poll *ent.Poll) PollResponse {
	return PollResponse{
		ID:          poll.ID,
		Title:       poll.Title,
		Description: poll.Description,
		Options:     poll.Options,
		OwnerID:     poll.OwnerID,
		CreatedAt:   poll.CreatedAt.Format("2006-01-02T15:04:05Z07:00"),
		UpdatedAt:   poll.UpdatedAt.Format("2006-01-02T15:04:05Z07:00"),
	}
}
