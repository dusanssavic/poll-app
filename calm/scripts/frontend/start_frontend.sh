#!/bin/bash
# Start frontend service with proper configuration
#
# Environment Variables (can be set before running this script):
#   BACKEND_HOST - Backend API server hostname/IP (default: 10.103.224.238)
#   BACKEND_PORT - Backend API server port (default: 8080)
#   FRONTEND_PORT - Frontend service port (default: 3000)
#   FRONTEND_HOST - Frontend service bind address (default: 0.0.0.0)
#
# Example usage:
#   export BACKEND_HOST=10.103.224.238
#   ./start_frontend.sh

set -e

# Set defaults for environment variables
BACKEND_HOST="@@{Backend.address}@@"
BACKEND_PORT="${BACKEND_PORT:-8080}"
API_BASE_URL="http://${BACKEND_HOST}:${BACKEND_PORT}"
FRONTEND_PORT="${FRONTEND_PORT:-3000}"
FRONTEND_HOST="${FRONTEND_HOST:-0.0.0.0}"

APP_DIR="/opt/poll-app"
FRONTEND_DIR="${APP_DIR}/frontend"
SERVICE_NAME="poll-app-frontend"

echo "Starting frontend service..."
echo "Backend API URL: ${API_BASE_URL}"

# Verify build exists
if [ ! -d "${FRONTEND_DIR}/build" ]; then
    echo "Error: Frontend build not found at ${FRONTEND_DIR}/build"
    exit 1
fi

# Verify Node.js and npm are available
if ! command -v node &> /dev/null || ! command -v npm &> /dev/null; then
    echo "Error: Node.js or npm is not installed"
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
Environment="PORT=${FRONTEND_PORT}"
Environment="HOST=${FRONTEND_HOST}"
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

# Configure firewall to allow frontend port
echo "Configuring firewall for port ${FRONTEND_PORT}..."
if command -v firewall-cmd &> /dev/null; then
    # Check if firewalld is running
    if systemctl is-active --quiet firewalld; then
        # Add port to firewall (permanent and runtime)
        firewall-cmd --permanent --add-port=${FRONTEND_PORT}/tcp || {
            echo "Warning: Failed to add port to firewall permanently"
        }
        firewall-cmd --add-port=${FRONTEND_PORT}/tcp || {
            echo "Warning: Failed to add port to firewall runtime"
        }
        # Reload firewall to apply permanent changes
        firewall-cmd --reload || {
            echo "Warning: Failed to reload firewall"
        }
        echo "Firewall configured for port ${FRONTEND_PORT}"
    else
        echo "Warning: firewalld is not running, skipping firewall configuration"
    fi
elif command -v iptables &> /dev/null; then
    # Fallback to iptables if firewalld is not available
    iptables -I INPUT -p tcp --dport ${FRONTEND_PORT} -j ACCEPT || {
        echo "Warning: Failed to add iptables rule"
    }
    # Try to save iptables rules (varies by distribution)
    if command -v iptables-save &> /dev/null && command -v iptables-restore &> /dev/null; then
        iptables-save > /etc/iptables/rules.v4 2>/dev/null || {
            echo "Warning: Could not save iptables rules"
        }
    fi
    echo "iptables configured for port ${FRONTEND_PORT}"
else
    echo "Warning: No firewall management tool found (firewalld or iptables)"
fi

# Start the service
echo "Starting ${SERVICE_NAME}..."
systemctl start "${SERVICE_NAME}"

# Wait a moment for service to start
sleep 3

# Verify service is listening on the expected port
echo "Verifying service is listening on port ${FRONTEND_PORT}..."
LISTENING=false
for i in {1..10}; do
    if command -v ss &> /dev/null; then
        if ss -tuln | grep -q ":${FRONTEND_PORT} "; then
            LISTENING=true
            echo "Service is listening on port ${FRONTEND_PORT}"
            ss -tuln | grep ":${FRONTEND_PORT} " || true
            break
        fi
    elif command -v netstat &> /dev/null; then
        if netstat -tuln | grep -q ":${FRONTEND_PORT} "; then
            LISTENING=true
            echo "Service is listening on port ${FRONTEND_PORT}"
            netstat -tuln | grep ":${FRONTEND_PORT} " || true
            break
        fi
    fi
    if [ $i -lt 10 ]; then
        sleep 1
    fi
done

if [ "$LISTENING" = false ]; then
    echo "Warning: Service may not be listening on port ${FRONTEND_PORT}"
    echo "Checking service logs..."
    journalctl -u "${SERVICE_NAME}" -n 20 --no-pager || true
fi

# Show service status
echo "Service status:"
systemctl status "${SERVICE_NAME}" --no-pager -l || true

echo "Frontend service started successfully."
echo "Service is available at http://${FRONTEND_HOST}:${FRONTEND_PORT}"
echo "API Base URL: ${API_BASE_URL}"
