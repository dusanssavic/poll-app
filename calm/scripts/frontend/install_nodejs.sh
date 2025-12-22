#!/bin/bash
# Install Node.js 20 on Rocky Linux 8.9

set -e

NODE_VERSION="${NODE_VERSION:-20}"

echo "Installing Node.js ${NODE_VERSION} on Rocky Linux 8.9..."

# Install prerequisites (curl is needed for NodeSource repository setup)
echo "Installing prerequisites..."
if ! command -v curl &> /dev/null; then
    dnf install -y curl || {
        echo "Error: Failed to install curl"
        exit 1
    }
    # Update PATH to ensure curl is available
    export PATH="/usr/bin:/bin:$PATH"
    # Verify curl is now available
    if ! command -v curl &> /dev/null; then
        echo "Error: curl installation failed or not in PATH"
        exit 1
    fi
else
    echo "curl is already installed"
fi

# Check if NodeSource repository is already installed (idempotency)
echo "Checking if NodeSource repository is installed..."
if [ -f "/etc/yum.repos.d/nodesource*.repo" ] || dnf repolist enabled | grep -q "nodesource"; then
    echo "NodeSource repository appears to be already installed."
else
    # Install NodeSource repository
    echo "Installing NodeSource repository..."
    curl -fsSL https://rpm.nodesource.com/setup_${NODE_VERSION}.x | bash - || {
        echo "Error: Failed to add NodeSource repository"
        exit 1
    }
    echo "NodeSource repository installed successfully."
    
    # Refresh metadata after adding repository
    # This is critical - dnf needs to download metadata from the newly added repository
    # Use --assumeyes to automatically accept GPG key imports
    echo "Refreshing dnf metadata to include NodeSource repository..."
    if dnf makecache --assumeyes; then
        echo "dnf metadata refreshed successfully."
    else
        echo "Warning: dnf makecache encountered some issues after adding NodeSource repository"
        echo "Continuing anyway - package installation will confirm if repository is accessible"
    fi
fi

# Install Node.js
echo "Installing Node.js..."
dnf install -y nodejs || {
    echo "Error: Failed to install Node.js"
    exit 1
}

# Verify installation
if ! command -v node &> /dev/null || ! node --version > /dev/null 2>&1; then
    echo "Error: Node.js installation failed"
    exit 1
fi

echo "Node.js installation completed."
