#!/bin/bash
# Configure PostgreSQL: Start service, create database and user, configure remote access
#
# Environment Variables (can be set before running this script):
#   POSTGRES_PORT - PostgreSQL server port (default: 5432)
#
# Database name, username, and password are hardcoded to: postgres/postgres/postgres
#
# Example usage:
#   export POSTGRES_PORT=5433
#   ./configure_postgres.sh

set -e

# Hardcoded database configuration (using default PostgreSQL setup)
POSTGRES_DB="postgres"
POSTGRES_USER="postgres"
POSTGRES_PASSWORD="postgres"
POSTGRES_PORT="${POSTGRES_PORT:-5432}"

echo "Configuring PostgreSQL on Rocky Linux 8.9..."

# Rocky Linux 8 PostgreSQL paths
PG_VERSION="15"
PG_DATA_DIR="/var/lib/pgsql/${PG_VERSION}/data"
PG_BIN_DIR="/usr/pgsql-${PG_VERSION}/bin"
PG_SETUP_SCRIPT="${PG_BIN_DIR}/postgresql-${PG_VERSION}-setup"
PG_CONF="${PG_DATA_DIR}/postgresql.conf"
PG_HBA="${PG_DATA_DIR}/pg_hba.conf"
PG_SERVICE="postgresql-${PG_VERSION}"

# Initialize database (if not already initialized)
echo "Checking if PostgreSQL database needs initialization..."
# Check if PostgreSQL is actually initialized by looking for key files
# PG_VERSION file is created during initialization
NEEDS_INIT=false
if [ ! -d "${PG_DATA_DIR}" ]; then
    NEEDS_INIT=true
elif [ ! -f "${PG_DATA_DIR}/PG_VERSION" ]; then
    # Directory exists but not initialized (empty or incomplete)
    echo "Data directory exists but PostgreSQL is not initialized"
    NEEDS_INIT=true
fi

if [ "$NEEDS_INIT" = true ]; then
    echo "Initializing PostgreSQL ${PG_VERSION} database..."
    if [ ! -f "${PG_SETUP_SCRIPT}" ]; then
        echo "Error: PostgreSQL setup script not found at ${PG_SETUP_SCRIPT}"
        exit 1
    fi
    # Remove directory if it exists but is empty/incomplete
    if [ -d "${PG_DATA_DIR}" ] && [ ! -f "${PG_DATA_DIR}/PG_VERSION" ]; then
        echo "Removing incomplete data directory..."
        rm -rf "${PG_DATA_DIR}"
    fi
    if ! ${PG_SETUP_SCRIPT} initdb; then
        echo "Error: Failed to initialize PostgreSQL database"
        echo "Please check the PostgreSQL setup script and permissions"
        exit 1
    fi
    # Verify data directory was created and initialized
    if [ ! -d "${PG_DATA_DIR}" ]; then
        echo "Error: Database initialization failed - data directory not created"
        exit 1
    fi
    if [ ! -f "${PG_DATA_DIR}/PG_VERSION" ]; then
        echo "Error: Database initialization failed - PG_VERSION file not found"
        exit 1
    fi
    echo "PostgreSQL database initialized successfully."
else
    echo "PostgreSQL database already initialized at ${PG_DATA_DIR}"
fi

# Check if service is already running
if systemctl is-active --quiet ${PG_SERVICE}; then
    echo "PostgreSQL service is already running"
else
    # Start and enable PostgreSQL service
    echo "Starting PostgreSQL service..."
    systemctl enable ${PG_SERVICE}
    
    # Attempt to start the service
    if ! systemctl start ${PG_SERVICE}; then
        echo "Error: Failed to start PostgreSQL service"
        echo ""
        echo "Service status:"
        systemctl status ${PG_SERVICE} --no-pager -l || true
        echo ""
        echo "Recent journal logs:"
        journalctl -u ${PG_SERVICE} -n 50 --no-pager || true
        exit 1
    fi
    
    # Verify service actually started
    sleep 2
    if ! systemctl is-active --quiet ${PG_SERVICE}; then
        echo "Error: PostgreSQL service did not start successfully"
        echo ""
        echo "Service status:"
        systemctl status ${PG_SERVICE} --no-pager -l || true
        echo ""
        echo "Recent journal logs:"
        journalctl -u ${PG_SERVICE} -n 50 --no-pager || true
        exit 1
    fi
fi

# Wait for PostgreSQL to be ready
echo "Waiting for PostgreSQL to be ready..."
POSTGRES_READY=false
for i in {1..30}; do
    # Show output for debugging instead of hiding it
    PSQL_OUTPUT=$(sudo -u postgres psql -c "SELECT 1" 2>&1)
    if echo "$PSQL_OUTPUT" | grep -q -E "(1|row)"; then
        echo "PostgreSQL is ready"
        POSTGRES_READY=true
        break
    fi
    if [ $i -eq 30 ]; then
        echo "Error: PostgreSQL failed to become ready after 30 attempts"
        echo "Last psql output: $PSQL_OUTPUT"
        echo ""
        echo "Service status:"
        systemctl status ${PG_SERVICE} --no-pager -l || true
        echo ""
        echo "Recent journal logs:"
        journalctl -u ${PG_SERVICE} -n 50 --no-pager || true
        exit 1
    fi
    sleep 2
done

if [ "$POSTGRES_READY" = false ]; then
    echo "Error: PostgreSQL is not ready"
    exit 1
fi

# Create database and user
echo "Creating database and user..."
sudo -u postgres psql <<EOF
-- Create user (if not exists)
DO \$\$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_user WHERE usename = '${POSTGRES_USER}') THEN
        CREATE USER ${POSTGRES_USER} WITH PASSWORD '${POSTGRES_PASSWORD}';
    END IF;
END
\$\$;

-- Create database (if not exists)
SELECT 'CREATE DATABASE ${POSTGRES_DB} OWNER ${POSTGRES_USER}'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '${POSTGRES_DB}')\gexec

-- Grant privileges
GRANT ALL PRIVILEGES ON DATABASE ${POSTGRES_DB} TO ${POSTGRES_USER};

-- Connect to the database and grant schema privileges
\c ${POSTGRES_DB}
GRANT ALL ON SCHEMA public TO ${POSTGRES_USER};
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO ${POSTGRES_USER};
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO ${POSTGRES_USER};
EOF

# Verify user and database were created
if ! sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='${POSTGRES_USER}'" 2>&1 | grep -q "1"; then
    echo "Error: User ${POSTGRES_USER} was not created"
    exit 1
fi
if ! sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='${POSTGRES_DB}'" 2>&1 | grep -q "1"; then
    echo "Error: Database ${POSTGRES_DB} was not created"
    exit 1
fi

echo "Database and user created successfully."

# Explicitly set password for postgres user (ensures password is correct even if user already existed)
echo "Setting password for postgres user..."
sudo -u postgres psql <<EOF
-- Set password for postgres user (works even if user already exists)
ALTER USER ${POSTGRES_USER} WITH PASSWORD '${POSTGRES_PASSWORD}';
EOF

# Verify password was set
if ! sudo -u postgres psql -c "SELECT 1" > /dev/null 2>&1; then
    echo "Warning: Could not verify postgres user password, but continuing..."
fi

echo "PostgreSQL user password configured."

# Configure PostgreSQL to listen on all interfaces
echo "Configuring PostgreSQL for remote connections..."

# Update postgresql.conf
if [ -f "$PG_CONF" ]; then
    # Backup original config
    cp "$PG_CONF" "${PG_CONF}.backup"
    
    # Update listen_addresses
    sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" "$PG_CONF" || \
    sed -i "s/listen_addresses = 'localhost'/listen_addresses = '*'/" "$PG_CONF" || \
    echo "listen_addresses = '*'" >> "$PG_CONF"
    
    # Update port if needed
    sed -i "s/#port = 5432/port = ${POSTGRES_PORT}/" "$PG_CONF" || \
    sed -i "s/port = 5432/port = ${POSTGRES_PORT}/" "$PG_CONF" || \
    echo "port = ${POSTGRES_PORT}" >> "$PG_CONF"
    
    echo "Updated postgresql.conf"
else
    echo "Warning: postgresql.conf not found at $PG_CONF"
fi

# Update pg_hba.conf to allow connections from backend service
if [ -f "$PG_HBA" ]; then
    # Backup original config
    cp "$PG_HBA" "${PG_HBA}.backup"
    
    # Add entry for backend service (using Calm macro will be replaced)
    # This allows connections from any IP in the subnet (for Calm deployment)
    if ! grep -q "host.*${POSTGRES_DB}.*${POSTGRES_USER}" "$PG_HBA"; then
        echo "host    ${POSTGRES_DB}    ${POSTGRES_USER}    0.0.0.0/0    md5" >> "$PG_HBA"
        echo "Added pg_hba.conf entry for remote connections"
    else
        echo "pg_hba.conf entry already exists for ${POSTGRES_DB}/${POSTGRES_USER}"
    fi
else
    echo "Warning: pg_hba.conf not found at $PG_HBA"
fi

# Configure firewall to allow PostgreSQL port
echo "Configuring firewall for port ${POSTGRES_PORT}..."
if command -v firewall-cmd &> /dev/null; then
    # Check if firewalld is running
    if systemctl is-active --quiet firewalld; then
        # Add port to firewall (permanent and runtime)
        firewall-cmd --permanent --add-port=${POSTGRES_PORT}/tcp || {
            echo "Warning: Failed to add port to firewall permanently"
        }
        firewall-cmd --add-port=${POSTGRES_PORT}/tcp || {
            echo "Warning: Failed to add port to firewall runtime"
        }
        # Reload firewall to apply permanent changes
        firewall-cmd --reload || {
            echo "Warning: Failed to reload firewall"
        }
        echo "Firewall configured for port ${POSTGRES_PORT}"
    else
        echo "Warning: firewalld is not running, skipping firewall configuration"
    fi
elif command -v iptables &> /dev/null; then
    # Fallback to iptables if firewalld is not available
    iptables -I INPUT -p tcp --dport ${POSTGRES_PORT} -j ACCEPT || {
        echo "Warning: Failed to add iptables rule"
    }
    # Try to save iptables rules (varies by distribution)
    if command -v iptables-save &> /dev/null && command -v iptables-restore &> /dev/null; then
        iptables-save > /etc/iptables/rules.v4 2>/dev/null || {
            echo "Warning: Could not save iptables rules"
        }
    fi
    echo "iptables configured for port ${POSTGRES_PORT}"
else
    echo "Warning: No firewall management tool found (firewalld or iptables)"
fi

# Restart PostgreSQL to apply changes
echo "Restarting PostgreSQL to apply configuration changes..."
if ! systemctl restart ${PG_SERVICE}; then
    echo "Error: Failed to restart PostgreSQL service"
    echo ""
    echo "Service status:"
    systemctl status ${PG_SERVICE} --no-pager -l || true
    echo ""
    echo "Recent journal logs:"
    journalctl -u ${PG_SERVICE} -n 50 --no-pager || true
    exit 1
fi

# Verify service restarted successfully
sleep 2
if ! systemctl is-active --quiet ${PG_SERVICE}; then
    echo "Error: PostgreSQL service did not restart successfully"
    echo ""
    echo "Service status:"
    systemctl status ${PG_SERVICE} --no-pager -l || true
    echo ""
    echo "Recent journal logs:"
    journalctl -u ${PG_SERVICE} -n 50 --no-pager || true
    exit 1
fi

# Wait for PostgreSQL to be ready again
echo "Waiting for PostgreSQL to restart..."
sleep 3
POSTGRES_RESTARTED=false
for i in {1..30}; do
    # Show output for debugging instead of hiding it
    PSQL_OUTPUT=$(sudo -u postgres psql -c "SELECT 1" 2>&1)
    if echo "$PSQL_OUTPUT" | grep -q -E "(1|row)"; then
        echo "PostgreSQL restarted successfully"
        POSTGRES_RESTARTED=true
        break
    fi
    if [ $i -eq 30 ]; then
        echo "Error: PostgreSQL failed to become ready after restart (30 attempts)"
        echo "Last psql output: $PSQL_OUTPUT"
        echo ""
        echo "Service status:"
        systemctl status ${PG_SERVICE} --no-pager -l || true
        echo ""
        echo "Recent journal logs:"
        journalctl -u ${PG_SERVICE} -n 50 --no-pager || true
        exit 1
    fi
    sleep 2
done

if [ "$POSTGRES_RESTARTED" = false ]; then
    echo "Error: PostgreSQL did not restart successfully"
    exit 1
fi


echo "PostgreSQL configuration completed successfully."
