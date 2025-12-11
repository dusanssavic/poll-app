package server

import (
	"fmt"
	"log"
	"net/http"

	"poll-app/auth"
	"poll-app/controller"
	"poll-app/service"
	"poll-app/storage"

	"github.com/julienschmidt/httprouter"
	"github.com/spf13/cobra"
)

func NewServerCommand() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "server",
		Short: "Start the backend server",
		Long:  "Start the HTTP server for the poll application backend",
		RunE:  runServer,
	}

	cmd.Flags().String("port", "8080", "Port to run the server on")
	cmd.Flags().String("host", "0.0.0.0", "Host to bind the server to")

	return cmd
}

func runServer(cmd *cobra.Command, args []string) error {
	port, _ := cmd.Flags().GetString("port")
	host, _ := cmd.Flags().GetString("host")

	// Initialize database
	dbClient, err := storage.NewClient()
	if err != nil {
		return fmt.Errorf("failed to initialize database: %w", err)
	}
	defer dbClient.Close()

	// Initialize Redis
	redisClient, err := auth.NewRedisClient()
	if err != nil {
		return fmt.Errorf("failed to initialize Redis: %w", err)
	}
	defer redisClient.Close()

	// Initialize JWT manager
	jwtManager, err := auth.NewJWTManager(redisClient)
	if err != nil {
		return fmt.Errorf("failed to initialize JWT manager: %w", err)
	}

	// Initialize storage
	storageLayer := storage.NewStorage(dbClient)

	// Initialize service
	serviceLayer := service.NewService(storageLayer)

	// Initialize controllers
	userController := controller.NewUserController(serviceLayer, jwtManager)
	pollController := controller.NewPollController(serviceLayer)
	voteController := controller.NewVoteController(serviceLayer)

	// Initialize router
	router := httprouter.New()

	// Health check endpoint
	router.GET("/health", healthCheck)

	// Auth middleware
	authMiddleware := auth.AuthMiddleware(jwtManager)

	// User routes (public)
	router.POST("/api/users", userController.CreateUser)
	router.POST("/api/users/login", userController.Login)
	router.POST("/api/users/refresh", userController.RefreshToken)

	// Poll routes
	router.GET("/api/polls", pollController.ListPolls)                         // Public
	router.GET("/api/polls/:id", pollController.GetPoll)                       // Public
	router.POST("/api/polls", authMiddleware(pollController.CreatePoll))       // Protected
	router.PUT("/api/polls/:id", authMiddleware(pollController.UpdatePoll))    // Protected
	router.DELETE("/api/polls/:id", authMiddleware(pollController.DeletePoll)) // Protected

	// Vote routes
	router.POST("/api/polls/:id/vote", authMiddleware(voteController.VoteOnPoll)) // Protected
	router.GET("/api/polls/:id/votes", voteController.GetVoteCounts)              // Public
	router.GET("/api/polls/:id/votes/:option", voteController.GetVotersByOption)  // Public

	addr := fmt.Sprintf("%s:%s", host, port)
	log.Printf("Starting server on %s", addr)

	return http.ListenAndServe(addr, router)
}

func healthCheck(w http.ResponseWriter, r *http.Request, _ httprouter.Params) {
	w.WriteHeader(http.StatusOK)
	if _, err := w.Write([]byte("We are Up!")); err != nil {
		log.Printf("Failed to write health check response: %v", err)
	}
}
