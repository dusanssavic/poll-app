#!/bin/bash
# Install Node.js 20 on Rocky Linux 8.9

set -e

NODE_VERSION="${NODE_VERSION:-20}"

echo "Installing Node.js ${NODE_VERSION} on Rocky Linux 8.9..."

# Install prerequisites
echo "Installing prerequisites..."
dnf install -y curl || {
    echo "Error: Failed to install curl"
    exit 1
}

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

# Verify Node.js package was installed
echo "Verifying Node.js installation..."
if ! rpm -q nodejs > /dev/null 2>&1; then
    echo "Error: Node.js package was not installed correctly"
    exit 1
fi
echo "Node.js package verified: $(rpm -q nodejs)"

# Verify installation and functionality
echo "Verifying Node.js functionality..."
if command -v node &> /dev/null; then
    NODE_VER=$(node --version)
    echo "Node.js installed successfully: $NODE_VER"
    
    # Verify node command works
    if ! node --version > /dev/null 2>&1; then
        echo "Error: Node.js command is available but not working correctly"
        exit 1
    fi
else
    echo "Error: Node.js installation failed - node command not found"
    exit 1
fi

# Verify npm is available
if command -v npm &> /dev/null; then
    NPM_VER=$(npm --version)
    echo "npm installed successfully: $NPM_VER"
    
    # Verify npm command works
    if ! npm --version > /dev/null 2>&1; then
        echo "Error: npm command is available but not working correctly"
        exit 1
    fi
else
    echo "Warning: npm command not found, but Node.js is installed"
    echo "npm should be included with Node.js installation"
fi

echo "Node.js installation completed."
