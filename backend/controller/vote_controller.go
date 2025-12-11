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

// VoteController handles vote-related HTTP requests
type VoteController struct {
	service service.VoteService
}

// NewVoteController creates a new vote controller
func NewVoteController(service service.VoteService) *VoteController {
	return &VoteController{service: service}
}

// VoteRequest represents the request body for voting
type VoteRequest struct {
	Option string `json:"option"`
}

// VoteResponse represents a vote in API responses
type VoteResponse struct {
	ID        uuid.UUID `json:"id"`
	UserID    uuid.UUID `json:"user_id"`
	PollID    uuid.UUID `json:"poll_id"`
	Option    string    `json:"option"`
	CreatedAt string    `json:"created_at"`
}

// VoteCountsResponse represents vote counts for a poll
type VoteCountsResponse struct {
	PollID uuid.UUID      `json:"poll_id"`
	Counts map[string]int `json:"counts"`
}

// VotersResponse represents voters for a specific option
type VotersResponse struct {
	PollID uuid.UUID  `json:"poll_id"`
	Option string     `json:"option"`
	Voters []UserInfo `json:"voters"`
}

// UserInfo represents basic user information
type UserInfo struct {
	ID       uuid.UUID `json:"id"`
	Email    string    `json:"email"`
	Username string    `json:"username"`
}

// VoteOnPoll handles POST /api/polls/:id/vote
func (c *VoteController) VoteOnPoll(w http.ResponseWriter, r *http.Request, ps httprouter.Params) {
	userID, ok := auth.GetUserIDFromContext(r.Context())
	if !ok {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}

	pollID, err := uuid.Parse(ps.ByName("id"))
	if err != nil {
		http.Error(w, "Invalid poll ID", http.StatusBadRequest)
		return
	}

	var req VoteRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid request body", http.StatusBadRequest)
		return
	}

	vote, err := c.service.VoteOnPoll(r.Context(), userID, pollID, req.Option)
	if err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(voteToResponse(vote))
}

// GetVoteCounts handles GET /api/polls/:id/votes
func (c *VoteController) GetVoteCounts(w http.ResponseWriter, r *http.Request, ps httprouter.Params) {
	pollID, err := uuid.Parse(ps.ByName("id"))
	if err != nil {
		http.Error(w, "Invalid poll ID", http.StatusBadRequest)
		return
	}

	counts, err := c.service.GetVoteCounts(r.Context(), pollID)
	if err != nil {
		if err.Error() == "poll not found" {
			http.Error(w, "Poll not found", http.StatusNotFound)
			return
		}
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	response := VoteCountsResponse{
		PollID: pollID,
		Counts: counts,
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

// GetVotersByOption handles GET /api/polls/:id/votes/:option
func (c *VoteController) GetVotersByOption(w http.ResponseWriter, r *http.Request, ps httprouter.Params) {
	pollID, err := uuid.Parse(ps.ByName("id"))
	if err != nil {
		http.Error(w, "Invalid poll ID", http.StatusBadRequest)
		return
	}

	option := ps.ByName("option")
	if option == "" {
		http.Error(w, "Option is required", http.StatusBadRequest)
		return
	}

	voters, err := c.service.GetVotersByOption(r.Context(), pollID, option)
	if err != nil {
		if err.Error() == "poll not found" || err.Error() == "option not found" {
			http.Error(w, err.Error(), http.StatusNotFound)
			return
		}
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	userInfos := make([]UserInfo, 0, len(voters))
	for _, voter := range voters {
		userInfos = append(userInfos, UserInfo{
			ID:       voter.ID,
			Email:    voter.Email,
			Username: voter.Username,
		})
	}

	response := VotersResponse{
		PollID: pollID,
		Option: option,
		Voters: userInfos,
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

// Helper function to convert ent.Vote to VoteResponse
func voteToResponse(vote *ent.Vote) VoteResponse {
	return VoteResponse{
		ID:        vote.ID,
		UserID:    vote.UserID,
		PollID:    vote.PollID,
		Option:    vote.Option,
		CreatedAt: vote.CreatedAt.Format("2006-01-02T15:04:05Z07:00"),
	}
}
