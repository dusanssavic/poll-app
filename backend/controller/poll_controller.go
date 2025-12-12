package controller

import (
	"encoding/json"
	"net/http"

	"poll-app/api"
	"poll-app/auth"
	"poll-app/converter"
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

// ListPolls handles GET /api/polls
func (c *PollController) ListPolls(w http.ResponseWriter, r *http.Request, _ httprouter.Params) {
	polls, err := c.service.ListPolls(r.Context())
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	responses := make([]api.PollResponse, 0, len(polls))
	for _, poll := range polls {
		responses = append(responses, converter.PollToResponse(poll))
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
	json.NewEncoder(w).Encode(converter.PollToResponse(poll))
}

// CreatePoll handles POST /api/polls
func (c *PollController) CreatePoll(w http.ResponseWriter, r *http.Request, _ httprouter.Params) {
	userID, ok := auth.GetUserIDFromContext(r.Context())
	if !ok {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}

	var req api.CreatePollRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid request body", http.StatusBadRequest)
		return
	}

	description := ""
	if req.Description != nil {
		description = *req.Description
	}

	poll, err := c.service.CreatePoll(r.Context(), req.Title, description, req.Options, userID)
	if err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(converter.PollToResponse(poll))
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

	var req api.UpdatePollRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid request body", http.StatusBadRequest)
		return
	}

	title := ""
	if req.Title != nil {
		title = *req.Title
	}
	description := ""
	if req.Description != nil {
		description = *req.Description
	}
	options := []string{}
	if req.Options != nil {
		options = *req.Options
	}

	poll, err := c.service.UpdatePoll(r.Context(), id, userID, title, description, options)
	if err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(converter.PollToResponse(poll))
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

