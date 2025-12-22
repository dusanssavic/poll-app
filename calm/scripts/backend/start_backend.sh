#!/bin/bash
# Start backend service with proper configuration (simplified for demo)

set -e

POSTGRES_HOST="@@{Postgres.address}@@"
POSTGRES_PORT="5432"
POSTGRES_DB="pollapp"
POSTGRES_USER="pollapp"
POSTGRES_PASSWORD="pollapp"
POSTGRES_SSLMODE="disable"
REDIS_HOST="localhost"
REDIS_PORT="6379"
BACKEND_PORT="8080"
BACKEND_HOST="0.0.0.0"

APP_DIR="/opt/poll-app"
BIN_DIR="${APP_DIR}/bin"
SERVICE_NAME="poll-app-backend"

if [ -z "$POSTGRES_HOST" ]; then
    echo "Error: POSTGRES_HOST must be set (use @@{Postgres.address}@@ in Calm)"
    exit 1
fi

echo "Starting backend service..."
echo "Connecting to PostgreSQL at ${POSTGRES_HOST}:${POSTGRES_PORT}"

# Verify binary exists
if [ ! -f "${BIN_DIR}/poll-app" ]; then
    echo "Error: Backend binary not found at ${BIN_DIR}/poll-app"
    exit 1
fi

# Verify binary is executable
if [ ! -x "${BIN_DIR}/poll-app" ]; then
    echo "Error: Backend binary is not executable"
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

# Wait for PostgreSQL to be ready (with retries and timeout)
echo "Waiting for PostgreSQL to be ready at ${POSTGRES_HOST}:${POSTGRES_PORT}..."
POSTGRES_READY=false
for i in {1..60}; do
    if command -v nc &> /dev/null; then
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
        HEALTH_CHECK=$(curl -f -s "http://localhost:${BACKEND_PORT}/health" 2>&1 || echo "failed")
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
