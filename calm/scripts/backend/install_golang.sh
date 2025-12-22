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

# Ensure we have a download tool (wget or curl)
HAS_WGET=false
HAS_CURL=false

if command -v wget &> /dev/null; then
    HAS_WGET=true
elif command -v curl &> /dev/null; then
    HAS_CURL=true
fi

# Install download tool if neither is available
if [ "$HAS_WGET" = false ] && [ "$HAS_CURL" = false ]; then
    echo "Installing wget or curl..."
    if command -v dnf &> /dev/null; then
        dnf install -y wget curl || {
            echo "Error: Failed to install wget or curl"
            exit 1
        }
    elif command -v yum &> /dev/null; then
        yum install -y wget curl || {
            echo "Error: Failed to install wget or curl"
            exit 1
        }
    else
        echo "Error: No download tool (wget/curl) available and no package manager found"
        exit 1
    fi
    
    # Update PATH to include newly installed tools
    export PATH="/usr/bin:/bin:$PATH"
    
    # Re-check for installed tools
    if command -v wget &> /dev/null; then
        HAS_WGET=true
    elif command -v curl &> /dev/null; then
        HAS_CURL=true
    else
        echo "Error: wget/curl installation failed or not in PATH"
        exit 1
    fi
fi

echo "Downloading Go from ${GO_URL}..."
cd /tmp

# Download using available tool
download_file() {
    local url=$1
    local output=$2
    if [ "$HAS_WGET" = true ]; then
        wget "$url" -O "$output" || return 1
    elif [ "$HAS_CURL" = true ]; then
        curl -L "$url" -o "$output" || return 1
    else
        echo "Error: No download tool available"
        return 1
    fi
}

if ! download_file "${GO_URL}" "${GO_TAR}"; then
    echo "Failed to download Go ${GO_VERSION}. Trying alternative version..."
    # Try alternative version if specific version not available
    GO_VERSION="1.21.0"
    GO_TAR="go${GO_VERSION}.linux-${GO_ARCH}.tar.gz"
    GO_URL="https://go.dev/dl/${GO_TAR}"
    if ! download_file "${GO_URL}" "${GO_TAR}"; then
        echo "Error: Failed to download Go"
        exit 1
    fi
fi

# Verify downloaded file exists
if [ ! -f "$GO_TAR" ]; then
    echo "Error: Downloaded file is missing"
    exit 1
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
if [ ! -f "${GO_ROOT}/bin/go" ]; then
    echo "Error: Go extraction failed"
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
if [ -f "${GO_ROOT}/bin/go" ]; then
    ${GO_ROOT}/bin/go version
else
    echo "Error: Go installation failed"
    exit 1
fi

echo "Golang installation completed."
