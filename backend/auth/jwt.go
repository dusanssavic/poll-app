package auth

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"errors"
	"fmt"
	"os"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
	"github.com/redis/go-redis/v9"
)

const (
	accessTokenTTL  = 15 * time.Minute
	refreshTokenTTL = 7 * 24 * time.Hour
)

// JWTClaims represents the JWT token claims
type JWTClaims struct {
	UserID   uuid.UUID `json:"user_id"`
	Email    string    `json:"email"`
	Username string    `json:"username"`
	jwt.RegisteredClaims
}

// RefreshTokenClaims represents refresh token claims with session ID
type RefreshTokenClaims struct {
	UserID    uuid.UUID `json:"user_id"`
	SessionID string    `json:"session_id"`
	jwt.RegisteredClaims
}

// JWTManager handles JWT token operations
type JWTManager struct {
	secretKey       []byte
	redisClient     *redis.Client
	accessTokenTTL  time.Duration
	refreshTokenTTL time.Duration
}

// NewJWTManager creates a new JWT manager
func NewJWTManager(redisClient *redis.Client) (*JWTManager, error) {
	secretKey := os.Getenv("JWT_SECRET_KEY")
	if secretKey == "" {
		secretKey = "default-secret-key-change-in-production"
	}

	return &JWTManager{
		secretKey:       []byte(secretKey),
		redisClient:     redisClient,
		accessTokenTTL:  accessTokenTTL,
		refreshTokenTTL: refreshTokenTTL,
	}, nil
}

// GenerateAccessToken generates a new access token
func (m *JWTManager) GenerateAccessToken(userID uuid.UUID, email, username string) (string, error) {
	claims := &JWTClaims{
		UserID:   userID,
		Email:    email,
		Username: username,
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(m.accessTokenTTL)),
			IssuedAt:  jwt.NewNumericDate(time.Now()),
			NotBefore: jwt.NewNumericDate(time.Now()),
		},
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString(m.secretKey)
}

// generateSessionID generates a unique session ID
func generateSessionID() (string, error) {
	bytes := make([]byte, 16)
	if _, err := rand.Read(bytes); err != nil {
		return "", err
	}
	return hex.EncodeToString(bytes), nil
}

// GenerateRefreshToken generates a new refresh token with session ID
func (m *JWTManager) GenerateRefreshToken(ctx context.Context, userID uuid.UUID) (string, string, error) {
	sessionID, err := generateSessionID()
	if err != nil {
		return "", "", fmt.Errorf("failed to generate session ID: %w", err)
	}

	claims := &RefreshTokenClaims{
		UserID:    userID,
		SessionID: sessionID,
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(m.refreshTokenTTL)),
			IssuedAt:  jwt.NewNumericDate(time.Now()),
			NotBefore: jwt.NewNumericDate(time.Now()),
		},
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	refreshToken, err := token.SignedString(m.secretKey)
	if err != nil {
		return "", "", err
	}

	// Store refresh token in Redis with session ID as part of the key
	// This allows multiple sessions per user
	key := fmt.Sprintf("refresh_token:%s:%s", userID.String(), sessionID)
	if err := m.redisClient.Set(ctx, key, refreshToken, m.refreshTokenTTL).Err(); err != nil {
		return "", "", fmt.Errorf("failed to store refresh token: %w", err)
	}

	// Also maintain a set of all session IDs for a user (for session management)
	userSessionsKey := fmt.Sprintf("user_sessions:%s", userID.String())
	if err := m.redisClient.SAdd(ctx, userSessionsKey, sessionID).Err(); err != nil {
		// If this fails, we should still clean up the token we just created
		m.redisClient.Del(ctx, key)
		return "", "", fmt.Errorf("failed to add session to user sessions: %w", err)
	}
	// Set expiration on the sessions set to match refresh token TTL
	m.redisClient.Expire(ctx, userSessionsKey, m.refreshTokenTTL)

	return refreshToken, sessionID, nil
}

// ValidateToken validates a JWT token and returns the claims
func (m *JWTManager) ValidateToken(tokenString string) (*JWTClaims, error) {
	token, err := jwt.ParseWithClaims(tokenString, &JWTClaims{}, func(token *jwt.Token) (interface{}, error) {
		if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, fmt.Errorf("unexpected signing method: %v", token.Header["alg"])
		}
		return m.secretKey, nil
	})

	if err != nil {
		return nil, err
	}

	if claims, ok := token.Claims.(*JWTClaims); ok && token.Valid {
		return claims, nil
	}

	return nil, errors.New("invalid token")
}

// ValidateRefreshToken validates a refresh token and checks Redis
func (m *JWTManager) ValidateRefreshToken(ctx context.Context, tokenString string) (*RefreshTokenClaims, error) {
	token, err := jwt.ParseWithClaims(tokenString, &RefreshTokenClaims{}, func(token *jwt.Token) (interface{}, error) {
		if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, fmt.Errorf("unexpected signing method: %v", token.Header["alg"])
		}
		return m.secretKey, nil
	})

	if err != nil {
		return nil, err
	}

	claims, ok := token.Claims.(*RefreshTokenClaims)
	if !ok || !token.Valid {
		return nil, errors.New("invalid token")
	}

	// Check if refresh token exists in Redis
	key := fmt.Sprintf("refresh_token:%s:%s", claims.UserID.String(), claims.SessionID)
	storedToken, err := m.redisClient.Get(ctx, key).Result()
	if err == redis.Nil {
		return nil, errors.New("refresh token not found")
	}
	if err != nil {
		return nil, fmt.Errorf("failed to get refresh token: %w", err)
	}

	if storedToken != tokenString {
		return nil, errors.New("invalid refresh token")
	}

	return claims, nil
}

// RevokeRefreshToken revokes a specific refresh token by session ID
func (m *JWTManager) RevokeRefreshToken(ctx context.Context, userID uuid.UUID, sessionID string) error {
	key := fmt.Sprintf("refresh_token:%s:%s", userID.String(), sessionID)

	// Remove from Redis
	if err := m.redisClient.Del(ctx, key).Err(); err != nil {
		return fmt.Errorf("failed to delete refresh token: %w", err)
	}

	// Remove from user sessions set
	userSessionsKey := fmt.Sprintf("user_sessions:%s", userID.String())
	if err := m.redisClient.SRem(ctx, userSessionsKey, sessionID).Err(); err != nil {
		// Log but don't fail - the token is already deleted
		return nil
	}

	return nil
}

// RevokeAllUserRefreshTokens revokes all refresh tokens for a user
func (m *JWTManager) RevokeAllUserRefreshTokens(ctx context.Context, userID uuid.UUID) error {
	userSessionsKey := fmt.Sprintf("user_sessions:%s", userID.String())

	// Get all session IDs for this user
	sessionIDs, err := m.redisClient.SMembers(ctx, userSessionsKey).Result()
	if err != nil && err != redis.Nil {
		return fmt.Errorf("failed to get user sessions: %w", err)
	}

	// Delete all refresh tokens
	for _, sessionID := range sessionIDs {
		key := fmt.Sprintf("refresh_token:%s:%s", userID.String(), sessionID)
		if err := m.redisClient.Del(ctx, key).Err(); err != nil {
			// Continue deleting others even if one fails
			continue
		}
	}

	// Delete the sessions set
	if err := m.redisClient.Del(ctx, userSessionsKey).Err(); err != nil && err != redis.Nil {
		return fmt.Errorf("failed to delete user sessions set: %w", err)
	}

	return nil
}

// RotateRefreshToken revokes the old refresh token and generates a new one
// Returns: newToken, newSessionID, userID, error
func (m *JWTManager) RotateRefreshToken(ctx context.Context, oldTokenString string) (string, string, uuid.UUID, error) {
	// Validate old token
	oldClaims, err := m.ValidateRefreshToken(ctx, oldTokenString)
	if err != nil {
		return "", "", uuid.Nil, fmt.Errorf("invalid refresh token: %w", err)
	}

	// Revoke old token
	if err := m.RevokeRefreshToken(ctx, oldClaims.UserID, oldClaims.SessionID); err != nil {
		return "", "", uuid.Nil, fmt.Errorf("failed to revoke old refresh token: %w", err)
	}

	// Generate new token
	newToken, newSessionID, err := m.GenerateRefreshToken(ctx, oldClaims.UserID)
	if err != nil {
		return "", "", uuid.Nil, fmt.Errorf("failed to generate new refresh token: %w", err)
	}

	return newToken, newSessionID, oldClaims.UserID, nil
}
