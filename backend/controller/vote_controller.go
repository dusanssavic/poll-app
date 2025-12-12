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
	openapi_types "github.com/oapi-codegen/runtime/types"
)

// VoteController handles vote-related HTTP requests
type VoteController struct {
	service service.VoteService
}

// NewVoteController creates a new vote controller
func NewVoteController(service service.VoteService) *VoteController {
	return &VoteController{service: service}
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

	var req api.VoteRequest
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
	json.NewEncoder(w).Encode(converter.VoteToResponse(vote))
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

	pollIDUUID := openapi_types.UUID(pollID)
	response := api.VoteCountsResponse{
		PollId: &pollIDUUID,
		Counts: &counts,
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

	userInfos := make([]api.UserInfo, 0, len(voters))
	for _, voter := range voters {
		userID := openapi_types.UUID(voter.ID)
		email := openapi_types.Email(voter.Email)
		username := voter.Username
		userInfos = append(userInfos, api.UserInfo{
			Id:       &userID,
			Email:    &email,
			Username: &username,
		})
	}

	pollIDUUID := openapi_types.UUID(pollID)
	response := api.VotersResponse{
		PollId: &pollIDUUID,
		Option: &option,
		Voters: &userInfos,
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

