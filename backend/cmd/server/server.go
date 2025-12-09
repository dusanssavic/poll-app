package server

import (
	"fmt"
	"log"
	"net/http"

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

	router := httprouter.New()

	// Health check endpoint
	router.GET("/health", healthCheck)

	// TODO: Add API routes
	// User routes
	// Poll routes

	addr := fmt.Sprintf("%s:%s", host, port)
	log.Printf("Starting server on %s", addr)

	return http.ListenAndServe(addr, router)
}

func healthCheck(w http.ResponseWriter, r *http.Request, _ httprouter.Params) {
	w.WriteHeader(http.StatusOK)
	if _, err := w.Write([]byte("OK")); err != nil {
		log.Printf("Failed to write health check response: %v", err)
	}
}
