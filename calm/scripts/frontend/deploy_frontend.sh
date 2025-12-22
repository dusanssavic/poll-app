#!/bin/bash
# Deploy frontend: Clone repository, install dependencies, build application

set -e

# Get variables from Calm (these will be replaced by Calm macros)
GITHUB_REPO_URL="${GITHUB_REPO_URL:-https://github.com/dusanssavic/poll-app}"
GITHUB_BRANCH="${GITHUB_BRANCH:-master}"
APP_DIR="/opt/poll-app"
FRONTEND_DIR="${APP_DIR}/frontend"

echo "Deploying frontend application..."

# Verify Node.js and npm are available
if ! command -v node &> /dev/null || ! command -v npm &> /dev/null; then
    echo "Error: Node.js or npm is not installed"
    exit 1
fi

# Create application directory
mkdir -p "$APP_DIR"

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

# Navigate to frontend directory
if [ ! -d "$FRONTEND_DIR" ]; then
    echo "Error: Frontend directory not found at $FRONTEND_DIR"
    exit 1
fi

cd "$FRONTEND_DIR"


# Install dependencies
echo "Installing npm dependencies..."
if ! npm ci; then
    echo "Error: Failed to install dependencies"
    exit 1
fi

# Generate API client from OpenAPI spec
echo "Generating API client from OpenAPI specification..."
if ! npm run generate-api; then
    echo "Error: Failed to generate API client"
    exit 1
fi

# Build the application
echo "Building frontend application..."
if ! npm run build; then
    echo "Error: Failed to build application"
    exit 1
fi

# Verify build output
if [ ! -d "${FRONTEND_DIR}/build" ]; then
    echo "Error: Build directory was not created"
    exit 1
fi

echo "Frontend application built successfully"
echo "Build output location: ${FRONTEND_DIR}/build"
ls -lh "${FRONTEND_DIR}/build" || true

echo "Frontend deployment completed successfully."
