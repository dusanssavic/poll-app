package converter

import (
	"poll-app/api"
	"poll-app/ent"

	openapi_types "github.com/oapi-codegen/runtime/types"
)

// PollToResponse converts an ent.Poll to api.PollResponse
func PollToResponse(poll *ent.Poll) api.PollResponse {
	id := openapi_types.UUID(poll.ID)
	ownerID := openapi_types.UUID(poll.OwnerID)
	createdAt := poll.CreatedAt
	updatedAt := poll.UpdatedAt
	title := poll.Title
	description := poll.Description
	options := poll.Options

	response := api.PollResponse{
		Id:          &id,
		Title:       &title,
		Description: &description,
		Options:     &options,
		OwnerId:     &ownerID,
		CreatedAt:   &createdAt,
		UpdatedAt:   &updatedAt,
	}

	// Calculate vote counts and voters by option if votes are loaded
	votes, err := poll.Edges.VotesOrErr()
	if err == nil && len(votes) > 0 {
		voteCounts := make(map[string]int)
		votersByOption := make(map[string][]api.UserInfo)

		for _, vote := range votes {
			// Count votes per option
			voteCounts[vote.Option]++

			// Add user info to voters_by_option if user is loaded
			if vote.Edges.User != nil {
				userID := openapi_types.UUID(vote.Edges.User.ID)
				email := openapi_types.Email(vote.Edges.User.Email)
				username := vote.Edges.User.Username
				userInfo := api.UserInfo{
					Id:       &userID,
					Email:    &email,
					Username: &username,
				}
				votersByOption[vote.Option] = append(votersByOption[vote.Option], userInfo)
			}
		}

		response.VoteCounts = &voteCounts
		response.VotersByOption = &votersByOption
	}

	return response
}

// VoteToResponse converts an ent.Vote to api.VoteResponse
func VoteToResponse(vote *ent.Vote) api.VoteResponse {
	id := openapi_types.UUID(vote.ID)
	userID := openapi_types.UUID(vote.UserID)
	pollID := openapi_types.UUID(vote.PollID)
	option := vote.Option
	createdAt := vote.CreatedAt

	return api.VoteResponse{
		Id:        &id,
		UserId:    &userID,
		PollId:    &pollID,
		Option:    &option,
		CreatedAt: &createdAt,
	}
}

