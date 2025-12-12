package controller

import (
	"encoding/json"
	"net/http"

	"poll-app/api"
	"poll-app/auth"
	"poll-app/service"

	"github.com/julienschmidt/httprouter"
	openapi_types "github.com/oapi-codegen/runtime/types"
)

// UserController handles user-related HTTP requests
type UserController struct {
	service    service.UserService
	jwtManager *auth.JWTManager
}

// NewUserController creates a new user controller
func NewUserController(service service.UserService, jwtManager *auth.JWTManager) *UserController {
	return &UserController{
		service:    service,
		jwtManager: jwtManager,
	}
}

// CreateUser handles POST /api/users
func (c *UserController) CreateUser(w http.ResponseWriter, r *http.Request, _ httprouter.Params) {
	var req api.CreateUserRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid request body", http.StatusBadRequest)
		return
	}

	user, err := c.service.CreateUser(r.Context(), string(req.Email), req.Username, req.Password)
	if err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	// Generate tokens
	accessToken, err := c.jwtManager.GenerateAccessToken(user.ID, user.Email, user.Username)
	if err != nil {
		http.Error(w, "Failed to generate access token", http.StatusInternalServerError)
		return
	}

	refreshToken, err := c.jwtManager.GenerateRefreshToken(user.ID)
	if err != nil {
		http.Error(w, "Failed to generate refresh token", http.StatusInternalServerError)
		return
	}

	userID := openapi_types.UUID(user.ID)
	email := openapi_types.Email(user.Email)
	response := api.AuthResponse{
		AccessToken:  &accessToken,
		RefreshToken: &refreshToken,
		UserId:       &userID,
		Email:        &email,
		Username:     &user.Username,
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(response)
}

// Login handles POST /api/users/login
func (c *UserController) Login(w http.ResponseWriter, r *http.Request, _ httprouter.Params) {
	var req api.LoginRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid request body", http.StatusBadRequest)
		return
	}

	user, err := c.service.Login(r.Context(), string(req.Email), req.Password)
	if err != nil {
		http.Error(w, err.Error(), http.StatusUnauthorized)
		return
	}

	// Generate tokens
	accessToken, err := c.jwtManager.GenerateAccessToken(user.ID, user.Email, user.Username)
	if err != nil {
		http.Error(w, "Failed to generate access token", http.StatusInternalServerError)
		return
	}

	refreshToken, err := c.jwtManager.GenerateRefreshToken(user.ID)
	if err != nil {
		http.Error(w, "Failed to generate refresh token", http.StatusInternalServerError)
		return
	}

	userID := openapi_types.UUID(user.ID)
	email := openapi_types.Email(user.Email)
	response := api.AuthResponse{
		AccessToken:  &accessToken,
		RefreshToken: &refreshToken,
		UserId:       &userID,
		Email:        &email,
		Username:     &user.Username,
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

// RefreshToken handles POST /api/users/refresh
func (c *UserController) RefreshToken(w http.ResponseWriter, r *http.Request, _ httprouter.Params) {
	var req api.RefreshTokenRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid request body", http.StatusBadRequest)
		return
	}

	claims, err := c.jwtManager.ValidateRefreshToken(req.RefreshToken)
	if err != nil {
		http.Error(w, "Invalid refresh token", http.StatusUnauthorized)
		return
	}

	// Get user to get email and username
	user, err := c.service.GetUserByID(r.Context(), claims.UserID)
	if err != nil {
		http.Error(w, "User not found", http.StatusNotFound)
		return
	}

	// Generate new tokens
	accessToken, err := c.jwtManager.GenerateAccessToken(user.ID, user.Email, user.Username)
	if err != nil {
		http.Error(w, "Failed to generate access token", http.StatusInternalServerError)
		return
	}

	refreshToken, err := c.jwtManager.GenerateRefreshToken(user.ID)
	if err != nil {
		http.Error(w, "Failed to generate refresh token", http.StatusInternalServerError)
		return
	}

	userID := openapi_types.UUID(user.ID)
	email := openapi_types.Email(user.Email)
	response := api.AuthResponse{
		AccessToken:  &accessToken,
		RefreshToken: &refreshToken,
		UserId:       &userID,
		Email:        &email,
		Username:     &user.Username,
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}
