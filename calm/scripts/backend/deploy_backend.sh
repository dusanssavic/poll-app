#!/bin/bash
# Deploy backend: Clone repository, build application

set -e

# Get variables from Calm (these will be replaced by Calm macros)
GITHUB_REPO_URL="${GITHUB_REPO_URL:-https://github.com/dusanssavic/poll-app}"
GITHUB_BRANCH="${GITHUB_BRANCH:-master}"
APP_DIR="/opt/poll-app"
BACKEND_DIR="${APP_DIR}/backend"
BIN_DIR="${APP_DIR}/bin"

echo "Deploying backend application..."

# Ensure Go is in PATH
export PATH=$PATH:/usr/local/go/bin
export GOROOT=/usr/local/go
export GOPATH=$HOME/go

# Verify Go is available
if ! command -v go &> /dev/null; then
    if [ -f "/usr/local/go/bin/go" ]; then
        export PATH=$PATH:/usr/local/go/bin
    else
        echo "Error: Go is not installed or not in PATH"
        exit 1
    fi
fi

# Verify Go is working
if ! go version > /dev/null 2>&1; then
    echo "Error: Go is installed but not working correctly"
    exit 1
fi

# Create application directory
mkdir -p "$APP_DIR"
mkdir -p "$BIN_DIR"

# Install Git if not present (idempotency check)
if ! command -v git &> /dev/null; then
    echo "Installing Git on Rocky Linux 8.9..."
    dnf install -y git || {
        echo "Error: Failed to install Git"
        exit 1
    }
else
    echo "Git is already installed: $(git --version)"
fi

# Clone or update repository
if [ -d "$APP_DIR/.git" ]; then
    echo "Repository already exists. Updating..."
    cd "$APP_DIR"
    git fetch origin || {
        echo "Error: Failed to fetch from origin"
        exit 1
    }
    git checkout "$GITHUB_BRANCH" || git checkout -b "$GITHUB_BRANCH" origin/"$GITHUB_BRANCH" || {
        echo "Error: Failed to checkout branch $GITHUB_BRANCH"
        exit 1
    }
    git pull origin "$GITHUB_BRANCH" || {
        echo "Error: Failed to pull from origin"
        exit 1
    }
else
    echo "Cloning repository from ${GITHUB_REPO_URL}..."
    cd /opt
    rm -rf poll-app
    git clone -b "$GITHUB_BRANCH" "$GITHUB_REPO_URL" poll-app || {
        echo "Failed to clone repository with branch. Trying without branch specification..."
        git clone "$GITHUB_REPO_URL" poll-app || {
            echo "Error: Failed to clone repository"
            exit 1
        }
    }
fi

# Navigate to backend directory
if [ ! -d "$BACKEND_DIR" ]; then
    echo "Error: Backend directory not found at $BACKEND_DIR"
    exit 1
fi

cd "$BACKEND_DIR"

# Verify go.mod exists
if [ ! -f "go.mod" ]; then
    echo "Error: go.mod not found in backend directory"
    exit 1
fi

# Download dependencies
echo "Downloading Go dependencies..."
if ! go mod download; then
    echo "Error: Failed to download Go dependencies"
    exit 1
fi

# Verify dependencies were downloaded
if [ ! -d "vendor" ] && [ ! -f "go.sum" ]; then
    echo "Warning: No vendor directory or go.sum file found after dependency download"
    echo "This may be normal if using Go modules without vendoring"
fi

# Build the application
echo "Building backend application..."
if ! CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o "${BIN_DIR}/poll-app" main.go; then
    echo "Error: Failed to build application"
    exit 1
fi

# Make binary executable
chmod +x "${BIN_DIR}/poll-app"

# Verify binary was created and is executable
if [ ! -f "${BIN_DIR}/poll-app" ]; then
    echo "Error: Binary was not created"
    exit 1
fi

if [ ! -x "${BIN_DIR}/poll-app" ]; then
    echo "Error: Binary is not executable"
    exit 1
fi

# Verify binary is not empty
if [ ! -s "${BIN_DIR}/poll-app" ]; then
    echo "Error: Binary file is empty"
    exit 1
fi

echo "Backend application built successfully at ${BIN_DIR}/poll-app"
ls -lh "${BIN_DIR}/poll-app"

# Try to get version info from binary if possible
if "${BIN_DIR}/poll-app" --version > /dev/null 2>&1 || "${BIN_DIR}/poll-app" version > /dev/null 2>&1; then
    echo "Binary appears to be functional"
fi

echo "Backend deployment completed successfully."
