#!/bin/bash
# Start frontend service with proper configuration (simplified for demo)

set -e

BACKEND_HOST="@@{Backend.address}@@"
BACKEND_PORT="8080"
API_BASE_URL="http://${BACKEND_HOST}:${BACKEND_PORT}"
FRONTEND_PORT="3000"
FRONTEND_HOST="0.0.0.0"

APP_DIR="/opt/poll-app"
FRONTEND_DIR="${APP_DIR}/frontend"
SERVICE_NAME="poll-app-frontend"

if [ -z "$BACKEND_HOST" ]; then
    echo "Error: BACKEND_HOST must be set (use @@{Backend.address}@@ in Calm)"
    exit 1
fi

echo "Starting frontend service..."
echo "Connecting to backend API at ${API_BASE_URL}"

# Verify build exists
if [ ! -d "${FRONTEND_DIR}/build" ]; then
    echo "Error: Frontend build not found at ${FRONTEND_DIR}/build"
    exit 1
fi

# Verify build directory is not empty
if [ -z "$(ls -A ${FRONTEND_DIR}/build 2>/dev/null)" ]; then
    echo "Error: Frontend build directory is empty"
    exit 1
fi

# Verify Node.js is available
if ! command -v node &> /dev/null; then
    echo "Error: Node.js is not installed or not in PATH"
    exit 1
fi

# Verify Node.js is working
if ! node --version > /dev/null 2>&1; then
    echo "Error: Node.js is installed but not working correctly"
    exit 1
fi

# Verify npm is available
if ! command -v npm &> /dev/null; then
    echo "Error: npm is not installed or not in PATH"
    exit 1
fi

# Verify npm is working
if ! npm --version > /dev/null 2>&1; then
    echo "Error: npm is installed but not working correctly"
    exit 1
fi

# Create systemd service file
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"

cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Poll App Frontend Service
After=network.target
Requires=network.target

[Service]
Type=simple
User=root
WorkingDirectory=${FRONTEND_DIR}
Environment="VITE_API_BASE_URL=${API_BASE_URL}"
ExecStart=/usr/bin/npm run start
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd and enable service
echo "Reloading systemd and enabling service..."
systemctl daemon-reload
systemctl enable "${SERVICE_NAME}"

# Wait for backend to be ready
echo "Waiting for backend API at ${API_BASE_URL}..."
BACKEND_READY=false
for i in {1..60}; do
    if command -v nc &> /dev/null; then
        if timeout 2 nc -z "${BACKEND_HOST}" "${BACKEND_PORT}" 2>&1; then
            # Show output for debugging instead of hiding it
            HEALTH_CHECK=$(curl -f -s "${API_BASE_URL}/health" 2>&1 || echo "failed")
            if echo "$HEALTH_CHECK" | grep -q -E "(ok|healthy|OK)"; then
                echo "Backend API is ready"
                BACKEND_READY=true
                break
            fi
        fi
    elif command -v timeout &> /dev/null; then
        if timeout 2 bash -c "echo > /dev/tcp/${BACKEND_HOST}/${BACKEND_PORT}" 2>&1; then
            # Show output for debugging instead of hiding it
            HEALTH_CHECK=$(curl -f -s "${API_BASE_URL}/health" 2>&1 || echo "failed")
            if echo "$HEALTH_CHECK" | grep -q -E "(ok|healthy|OK)"; then
                echo "Backend API is ready"
                BACKEND_READY=true
                break
            fi
        fi
    else
        # Show output for debugging instead of hiding it
        HEALTH_CHECK=$(curl -f -s "${API_BASE_URL}/health" 2>&1 || echo "failed")
        if echo "$HEALTH_CHECK" | grep -q -E "(ok|healthy|OK)"; then
            echo "Backend API is ready"
            BACKEND_READY=true
            break
        fi
    fi
    
    if [ $i -eq 60 ]; then
        echo "Warning: Backend API may not be ready after 60 attempts, but proceeding"
    fi
    sleep 2
done

if [ "$BACKEND_READY" = false ]; then
    echo "Warning: Could not verify backend API connectivity, but continuing..."
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
        if command -v nc &> /dev/null; then
            if timeout 2 nc -z localhost "${FRONTEND_PORT}" 2>&1; then
                echo "Frontend service is running on port ${FRONTEND_PORT}"
                SERVICE_READY=true
                break
            fi
        elif command -v timeout &> /dev/null; then
            if timeout 2 bash -c "echo > /dev/tcp/localhost/${FRONTEND_PORT}" 2>&1; then
                echo "Frontend service is running on port ${FRONTEND_PORT}"
                SERVICE_READY=true
                break
            fi
        else
            # If service is active, consider it ready
            if [ $i -ge 10 ]; then
                echo "Frontend service is running (port check not available, but service is active)"
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

echo "Frontend service started successfully."
echo "Service is available at http://${FRONTEND_HOST}:${FRONTEND_PORT}"
echo "API Base URL: ${API_BASE_URL}"
