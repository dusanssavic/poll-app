package main

import (
	"os"

	"poll-app/cmd/server"

	"github.com/spf13/cobra"
)

func main() {
	rootCmd := &cobra.Command{
		Use:   "poll-app",
		Short: "Poll application backend service",
		Long:  "A full-stack poll application backend with authentication, poll management, and voting functionality",
	}

	rootCmd.AddCommand(server.NewServerCommand())

	if err := rootCmd.Execute(); err != nil {
		os.Exit(1)
	}
}
