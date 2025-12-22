#!/bin/bash
# Configure PostgreSQL: Start service, create database and user, configure remote access

set -e

# Get variables from Calm (these will be replaced by Calm macros)
POSTGRES_DB="${POSTGRES_DB:-pollapp}"
POSTGRES_USER="${POSTGRES_USER:-pollapp}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD}"
POSTGRES_PORT="${POSTGRES_PORT:-5432}"

if [ -z "$POSTGRES_PASSWORD" ]; then
    echo "Error: POSTGRES_PASSWORD is not set"
    exit 1
fi

echo "Configuring PostgreSQL on Rocky Linux 8.9..."

# Rocky Linux 8 PostgreSQL paths
PG_VERSION="15"
PG_DATA_DIR="/var/lib/pgsql/${PG_VERSION}/data"
PG_CONF="${PG_DATA_DIR}/postgresql.conf"
PG_HBA="${PG_DATA_DIR}/pg_hba.conf"
PG_SERVICE="postgresql-${PG_VERSION}"

# Start and enable PostgreSQL service
echo "Starting PostgreSQL service..."
systemctl enable ${PG_SERVICE}
systemctl start ${PG_SERVICE}

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
        echo "Error: PostgreSQL failed to start after 30 attempts"
        echo "Last output: $PSQL_OUTPUT"
        systemctl status ${PG_SERVICE} --no-pager -l || true
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
# Capture output to verify creation
PSQL_CREATE_OUTPUT=$(sudo -u postgres psql <<EOF 2>&1
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
)

# Verify user was created
echo "Verifying user creation..."
USER_CHECK=$(sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='${POSTGRES_USER}'" 2>&1)
if [ "$USER_CHECK" != "1" ]; then
    echo "Error: User ${POSTGRES_USER} was not created successfully"
    echo "Output: $PSQL_CREATE_OUTPUT"
    exit 1
fi
echo "User ${POSTGRES_USER} verified"

# Verify database was created
echo "Verifying database creation..."
DB_CHECK=$(sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='${POSTGRES_DB}'" 2>&1)
if [ "$DB_CHECK" != "1" ]; then
    echo "Error: Database ${POSTGRES_DB} was not created successfully"
    echo "Output: $PSQL_CREATE_OUTPUT"
    exit 1
fi
echo "Database ${POSTGRES_DB} verified"

echo "Database and user created successfully."

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

# Restart PostgreSQL to apply changes
echo "Restarting PostgreSQL to apply configuration changes..."
systemctl restart ${PG_SERVICE}

# Wait for PostgreSQL to be ready again
echo "Waiting for PostgreSQL to restart..."
sleep 5
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
        echo "Error: PostgreSQL failed to restart after 30 attempts"
        echo "Last output: $PSQL_OUTPUT"
        systemctl status ${PG_SERVICE} --no-pager -l || true
        exit 1
    fi
    sleep 2
done

if [ "$POSTGRES_RESTARTED" = false ]; then
    echo "Error: PostgreSQL did not restart successfully"
    exit 1
fi

# Verify configuration
echo "Verifying PostgreSQL configuration..."
DB_LIST=$(sudo -u postgres psql -c "\l" 2>&1)
if echo "$DB_LIST" | grep -q "${POSTGRES_DB}"; then
    echo "Database ${POSTGRES_DB} exists and is accessible"
else
    echo "Warning: Database ${POSTGRES_DB} not found in database list"
    echo "Database list output: $DB_LIST"
fi

# Verify remote connection configuration
if grep -q "listen_addresses = '\*'" "$PG_CONF" 2>/dev/null || grep -q "listen_addresses = '*'" "$PG_CONF" 2>/dev/null; then
    echo "PostgreSQL is configured to listen on all interfaces"
else
    echo "Warning: PostgreSQL may not be configured to listen on all interfaces"
fi

echo "PostgreSQL configuration completed successfully."
