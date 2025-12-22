#!/bin/bash
# Install and configure Redis server on Rocky Linux 8.9

set -e

echo "Installing Redis server on Rocky Linux 8.9..."

# Check if EPEL repository is already installed (idempotency)
echo "Checking if EPEL repository is installed..."
if dnf repolist enabled | grep -q "epel" || rpm -q epel-release > /dev/null 2>&1; then
    echo "EPEL repository is already installed."
else
    # Install EPEL repository if not present
    echo "Installing EPEL repository..."
    dnf install -y epel-release || {
        echo "Error: Failed to install EPEL repository"
        exit 1
    }
    echo "EPEL repository installed successfully."
    
    # Refresh metadata after adding repository
    # Use --assumeyes to automatically accept GPG key imports
    echo "Refreshing dnf metadata..."
    dnf makecache --assumeyes || {
        echo "Warning: dnf makecache encountered some issues after adding EPEL repository"
    }
fi

# Install Redis
echo "Installing Redis..."
dnf install -y redis || {
    echo "Error: Failed to install Redis"
    exit 1
}

# Verify Redis package was installed
echo "Verifying Redis installation..."
if ! rpm -q redis > /dev/null 2>&1; then
    echo "Error: Redis package was not installed correctly"
    exit 1
fi
echo "Redis package verified: $(rpm -q redis)"

# Configure Redis to listen on localhost only (for security)
echo "Configuring Redis..."

REDIS_CONF="/etc/redis/redis.conf"
if [ ! -f "$REDIS_CONF" ]; then
    REDIS_CONF="/etc/redis.conf"
fi

if [ -f "$REDIS_CONF" ]; then
    # Backup original config
    cp "$REDIS_CONF" "${REDIS_CONF}.backup"
    
    # Ensure Redis listens on localhost only
    sed -i "s/^bind .*/bind 127.0.0.1/" "$REDIS_CONF" || \
    echo "bind 127.0.0.1" >> "$REDIS_CONF"
    
    # Disable protected mode for localhost connections
    sed -i "s/^protected-mode yes/protected-mode no/" "$REDIS_CONF" || \
    sed -i "s/^# protected-mode yes/protected-mode no/" "$REDIS_CONF"
    
    echo "Redis configuration updated"
else
    echo "Warning: Redis config file not found at $REDIS_CONF"
fi

# Verify systemd service file exists
echo "Verifying Redis service file..."
if [ ! -f "/usr/lib/systemd/system/redis.service" ]; then
    echo "Warning: Redis service file not found at /usr/lib/systemd/system/redis.service"
    echo "Service may not be available for management"
else
    echo "Redis service file found"
fi

# Start and enable Redis service
echo "Starting Redis service..."
systemctl enable redis
systemctl start redis

# Wait for Redis to be ready
echo "Waiting for Redis to be ready..."
for i in {1..30}; do
    # Show output for debugging instead of hiding it
    if redis-cli ping 2>&1 | grep -q "PONG"; then
        echo "Redis is ready"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "Error: Redis failed to start after 30 attempts"
        echo "Checking Redis service status..."
        systemctl status redis --no-pager -l || true
        exit 1
    fi
    sleep 1
done

# Verify Redis is running
echo "Verifying Redis is running..."
if redis-cli ping 2>&1 | grep -q "PONG"; then
    echo "Redis is running successfully"
    REDIS_INFO=$(redis-cli info server 2>&1 | grep "redis_version" || echo "version unknown")
    echo "Redis info: $REDIS_INFO"
else
    echo "Error: Redis may not be responding correctly"
    exit 1
fi

echo "Redis installation and configuration completed."
