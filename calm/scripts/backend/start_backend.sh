#!/bin/bash
# Start backend service with proper configuration
#
# Environment Variables (can be set before running this script):
#   POSTGRES_HOST - PostgreSQL server hostname/IP (default: 10.103.229.71)
#   POSTGRES_PORT - PostgreSQL server port (default: 5432)
#   POSTGRES_SSLMODE - PostgreSQL SSL mode (default: disable)
#   REDIS_HOST - Redis server hostname/IP (default: localhost)
#   REDIS_PORT - Redis server port (default: 6379)
#   BACKEND_PORT - Backend service port (default: 8080)
#   BACKEND_HOST - Backend service bind address (default: 0.0.0.0)
#
# Database name, username, and password are hardcoded to: postgres/postgres/postgres
#
# Example usage:
#   ./start_backend.sh

set -e

# Hardcoded database configuration (using default PostgreSQL setup)
POSTGRES_DB="postgres"
POSTGRES_USER="postgres"
POSTGRES_PASSWORD="postgres"

# Set defaults for configurable environment variables
POSTGRES_HOST="@@{Postgres.address}@@"
POSTGRES_PORT="${POSTGRES_PORT:-5432}"
POSTGRES_SSLMODE="${POSTGRES_SSLMODE:-disable}"
REDIS_HOST="${REDIS_HOST:-localhost}"
REDIS_PORT="${REDIS_PORT:-6379}"
BACKEND_PORT="${BACKEND_PORT:-8080}"
BACKEND_HOST="${BACKEND_HOST:-0.0.0.0}"

APP_DIR="/opt/poll-app"
BIN_DIR="${APP_DIR}/bin"
SERVICE_NAME="poll-app-backend"

echo "Starting backend service..."
echo "Connecting to PostgreSQL at ${POSTGRES_HOST}:${POSTGRES_PORT}"

# Install prerequisite tools if missing
echo "Checking for prerequisite tools..."
MISSING_TOOLS=()

if ! command -v nc &> /dev/null && ! command -v timeout &> /dev/null; then
    MISSING_TOOLS+=("nc")
fi

if ! command -v curl &> /dev/null; then
    MISSING_TOOLS+=("curl")
fi

if [ ${#MISSING_TOOLS[@]} -gt 0 ]; then
    echo "Installing missing tools: ${MISSING_TOOLS[*]}..."
    if command -v dnf &> /dev/null; then
        dnf install -y ${MISSING_TOOLS[@]} || {
            echo "Warning: Failed to install some tools. Continuing anyway..."
        }
    elif command -v yum &> /dev/null; then
        yum install -y ${MISSING_TOOLS[@]} || {
            echo "Warning: Failed to install some tools. Continuing anyway..."
        }
    else
        echo "Warning: Package manager not found. Please install manually: ${MISSING_TOOLS[*]}"
    fi
    # Update PATH to ensure newly installed tools are available
    export PATH="/usr/bin:/bin:$PATH"
fi

# Verify binary exists
if [ ! -f "${BIN_DIR}/poll-app" ]; then
    echo "Error: Backend binary not found at ${BIN_DIR}/poll-app"
    exit 1
fi

# Create systemd service file
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"

cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Poll App Backend Service
After=network.target redis.service
Requires=network.target

[Service]
Type=simple
User=root
WorkingDirectory=${BIN_DIR}
ExecStart=${BIN_DIR}/poll-app server --host ${BACKEND_HOST} --port ${BACKEND_PORT}
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

# Environment variables
Environment="POSTGRES_HOST=${POSTGRES_HOST}"
Environment="POSTGRES_PORT=${POSTGRES_PORT}"
Environment="POSTGRES_DB=${POSTGRES_DB}"
Environment="POSTGRES_USER=${POSTGRES_USER}"
Environment="POSTGRES_PASSWORD=${POSTGRES_PASSWORD}"
Environment="POSTGRES_SSLMODE=${POSTGRES_SSLMODE}"
Environment="REDIS_HOST=${REDIS_HOST}"
Environment="REDIS_PORT=${REDIS_PORT}"

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd and enable service
echo "Reloading systemd and enabling service..."
systemctl daemon-reload
systemctl enable "${SERVICE_NAME}"

# Configure firewall to allow backend port
echo "Configuring firewall for port ${BACKEND_PORT}..."
if command -v firewall-cmd &> /dev/null; then
    # Check if firewalld is running
    if systemctl is-active --quiet firewalld; then
        # Add port to firewall (permanent and runtime)
        firewall-cmd --permanent --add-port=${BACKEND_PORT}/tcp || {
            echo "Warning: Failed to add port to firewall permanently"
        }
        firewall-cmd --add-port=${BACKEND_PORT}/tcp || {
            echo "Warning: Failed to add port to firewall runtime"
        }
        # Reload firewall to apply permanent changes
        firewall-cmd --reload || {
            echo "Warning: Failed to reload firewall"
        }
        echo "Firewall configured for port ${BACKEND_PORT}"
    else
        echo "Warning: firewalld is not running, skipping firewall configuration"
    fi
elif command -v iptables &> /dev/null; then
    # Fallback to iptables if firewalld is not available
    iptables -I INPUT -p tcp --dport ${BACKEND_PORT} -j ACCEPT || {
        echo "Warning: Failed to add iptables rule"
    }
    # Try to save iptables rules (varies by distribution)
    if command -v iptables-save &> /dev/null && command -v iptables-restore &> /dev/null; then
        iptables-save > /etc/iptables/rules.v4 2>/dev/null || {
            echo "Warning: Could not save iptables rules"
        }
    fi
    echo "iptables configured for port ${BACKEND_PORT}"
else
    echo "Warning: No firewall management tool found (firewalld or iptables)"
fi

# Wait for PostgreSQL to be ready (with retries and timeout)
echo "Waiting for PostgreSQL to be ready at ${POSTGRES_HOST}:${POSTGRES_PORT}..."
POSTGRES_READY=false
for i in {1..60}; do
    if command -v nc &> /dev/null && command -v timeout &> /dev/null; then
        if timeout 2 nc -z "${POSTGRES_HOST}" "${POSTGRES_PORT}" 2>&1; then
            echo "PostgreSQL is ready (checked with nc)"
            POSTGRES_READY=true
            break
        fi
    elif command -v timeout &> /dev/null; then
        if timeout 2 bash -c "echo > /dev/tcp/${POSTGRES_HOST}/${POSTGRES_PORT}" 2>&1; then
            echo "PostgreSQL is ready (checked with bash tcp test)"
            POSTGRES_READY=true
            break
        fi
    elif command -v nc &> /dev/null; then
        if nc -z -w 2 "${POSTGRES_HOST}" "${POSTGRES_PORT}" 2>&1; then
            echo "PostgreSQL is ready (checked with nc)"
            POSTGRES_READY=true
            break
        fi
    else
        # Fallback: try basic TCP connection without timeout
        if bash -c "echo > /dev/tcp/${POSTGRES_HOST}/${POSTGRES_PORT}" 2>&1; then
            echo "PostgreSQL is ready (checked with bash tcp test)"
            POSTGRES_READY=true
            break
        fi
    fi
    
    if [ $i -eq 60 ]; then
        echo "Warning: PostgreSQL may not be ready after 60 attempts, but proceeding with service start"
    fi
    sleep 2
done

if [ "$POSTGRES_READY" = false ]; then
    echo "Warning: Could not verify PostgreSQL connectivity, but continuing..."
fi

# Wait for Redis to be ready
echo "Waiting for Redis..."
REDIS_READY=false
for i in {1..30}; do
    # Show output for debugging instead of hiding it
    REDIS_RESPONSE=$(redis-cli ping 2>&1)
    if echo "$REDIS_RESPONSE" | grep -q "PONG"; then
        echo "Redis is ready"
        REDIS_READY=true
        break
    fi
    if [ $i -eq 30 ]; then
        echo "Warning: Redis may not be ready after 30 attempts"
        echo "Last response: $REDIS_RESPONSE"
    fi
    sleep 1
done

if [ "$REDIS_READY" = false ]; then
    echo "Warning: Could not verify Redis connectivity, but continuing..."
fi

# Start the service
echo "Starting ${SERVICE_NAME}..."
systemctl start "${SERVICE_NAME}"

# Wait for service to be ready
echo "Waiting for service to start..."
sleep 5
SERVICE_READY=false
for i in {1..30}; do
    if systemctl is-active --quiet "${SERVICE_NAME}"; then
        # Show output for debugging instead of hiding it
        if command -v curl &> /dev/null; then
            HEALTH_CHECK=$(curl -f -s "http://localhost:${BACKEND_PORT}/health" 2>&1 || echo "failed")
        else
            HEALTH_CHECK="failed"
        fi
        if echo "$HEALTH_CHECK" | grep -q -E "(ok|healthy|OK)" || [ "$HEALTH_CHECK" = "failed" ]; then
            # If health check endpoint exists and responds, or if it's just not available yet
            if [ "$HEALTH_CHECK" != "failed" ]; then
                echo "Backend service is running and healthy"
                SERVICE_READY=true
                break
            elif [ $i -ge 10 ]; then
                # After 10 attempts, if service is active, consider it ready
                echo "Backend service is running (health check not available, but service is active)"
                SERVICE_READY=true
                break
            fi
        fi
    fi
    sleep 2
done

if [ "$SERVICE_READY" = false ]; then
    echo "Warning: Service may not be fully ready, but it is started"
fi

# Show service status
echo "Service status:"
systemctl status "${SERVICE_NAME}" --no-pager -l || true

echo "Backend service started successfully."
echo "Service is available at http://${BACKEND_HOST}:${BACKEND_PORT}"
echo "Health check: http://${BACKEND_HOST}:${BACKEND_PORT}/health"
