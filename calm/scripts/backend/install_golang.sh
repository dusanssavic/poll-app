#!/bin/bash
# Install Golang 1.25.5 (or latest compatible version)

set -e

GO_VERSION="${GO_VERSION:-1.25.5}"
INSTALL_DIR="/usr/local"
GO_ROOT="${INSTALL_DIR}/go"

echo "Installing Golang ${GO_VERSION}..."

# Detect OS architecture
ARCH=$(uname -m)
case $ARCH in
    x86_64)
        GO_ARCH="amd64"
        ;;
    aarch64|arm64)
        GO_ARCH="arm64"
        ;;
    *)
        echo "Error: Unsupported architecture: $ARCH"
        exit 1
        ;;
esac

# Download and install Go
GO_TAR="go${GO_VERSION}.linux-${GO_ARCH}.tar.gz"
GO_URL="https://go.dev/dl/${GO_TAR}"

echo "Downloading Go from ${GO_URL}..."
cd /tmp

# Remove -q flag to show download progress and prevent apparent hangs
if ! wget "${GO_URL}"; then
    echo "Failed to download Go ${GO_VERSION}. Trying alternative version..."
    # Try latest version if specific version not available
    GO_VERSION="1.21.0"
    GO_TAR="go${GO_VERSION}.linux-${GO_ARCH}.tar.gz"
    GO_URL="https://go.dev/dl/${GO_TAR}"
    if ! wget "${GO_URL}"; then
        echo "Error: Failed to download Go"
        exit 1
    fi
fi

# Verify downloaded file exists and is not empty
if [ ! -f "$GO_TAR" ] || [ ! -s "$GO_TAR" ]; then
    echo "Error: Downloaded file is missing or empty"
    exit 1
fi

# Verify it's a valid tar.gz file
if ! file "$GO_TAR" | grep -q "gzip compressed"; then
    echo "Warning: Downloaded file may not be a valid gzip archive"
    echo "Continuing anyway..."
fi

# Remove old installation if exists
if [ -d "$GO_ROOT" ]; then
    echo "Removing existing Go installation..."
    rm -rf "$GO_ROOT"
fi

# Extract Go
echo "Extracting Go..."
if ! tar -C "$INSTALL_DIR" -xzf "$GO_TAR"; then
    echo "Error: Failed to extract Go archive"
    exit 1
fi

# Verify extraction was successful
if [ ! -d "$GO_ROOT" ] || [ ! -f "${GO_ROOT}/bin/go" ]; then
    echo "Error: Go extraction failed or binary not found"
    exit 1
fi

# Clean up
rm -f "$GO_TAR"

# Set up environment variables
echo "Setting up Go environment..."

# Add to /etc/profile.d for system-wide availability
cat > /etc/profile.d/go.sh <<EOF
export PATH=\$PATH:${GO_ROOT}/bin
export GOPATH=\$HOME/go
export GOROOT=${GO_ROOT}
EOF

# Source it for current session
export PATH=$PATH:${GO_ROOT}/bin
export GOPATH=$HOME/go
export GOROOT=${GO_ROOT}

# Verify installation
echo "Verifying Go installation..."
if command -v go &> /dev/null; then
    GO_VER=$(go version)
    echo "Go installed successfully: $GO_VER"
    
    # Verify go command works
    if ! go version > /dev/null 2>&1; then
        echo "Error: Go command is available but not working correctly"
        exit 1
    fi
else
    # Try with full path
    if [ -f "${GO_ROOT}/bin/go" ]; then
        if ${GO_ROOT}/bin/go version > /dev/null 2>&1; then
            ${GO_ROOT}/bin/go version
            echo "Go installed at ${GO_ROOT}/bin/go"
            echo "Note: You may need to log out and log back in for 'go' command to be available in PATH"
        else
            echo "Error: Go binary exists but is not working correctly"
            exit 1
        fi
    else
        echo "Error: Go installation failed - binary not found"
        exit 1
    fi
fi

echo "Golang installation completed."
