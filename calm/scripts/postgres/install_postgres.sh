#!/bin/bash
# Install PostgreSQL 15 on Rocky Linux 8.9

set -e

# PostgreSQL version configuration
PG_VERSION="15"
PG_DATA_DIR="/var/lib/pgsql/${PG_VERSION}/data"
PG_BIN_DIR="/usr/pgsql-${PG_VERSION}/bin"
PG_SETUP_SCRIPT="${PG_BIN_DIR}/postgresql-${PG_VERSION}-setup"
PG_SERVICE="postgresql-${PG_VERSION}"

# PostgreSQL repository URL for Rocky Linux 8 (EL-8)
PG_REPO_URL="https://download.postgresql.org/pub/repos/yum/reporpms/EL-8-x86_64/pgdg-redhat-repo-latest.noarch.rpm"

# Package names
PG_SERVER_PKG="postgresql${PG_VERSION}-server"
PG_CONTRIB_PKG="postgresql${PG_VERSION}-contrib"

echo "Starting PostgreSQL ${PG_VERSION} installation on Rocky Linux 8.9..."

# Clean dnf cache to ensure fresh package metadata
# This is done before makecache to clear any stale or corrupted cache
echo "Cleaning dnf cache..."
if dnf clean all; then
    echo "dnf cache cleaned successfully."
else
    echo "Warning: dnf clean all encountered some issues, but continuing..."
    echo "This is usually safe to ignore if repositories are properly configured."
fi

# Rebuild dnf cache from configured repositories
# This ensures we have up-to-date package information before proceeding
echo "Rebuilding dnf cache from configured repositories..."
if dnf makecache; then
    echo "dnf cache rebuilt successfully."
else
    echo "Warning: dnf makecache encountered some issues."
    echo "This may indicate repository configuration problems, but continuing..."
    echo "The installation will fail later if packages cannot be found."
fi

# Check if PostgreSQL repository is already installed (idempotency)
echo "Checking if PostgreSQL repository is already installed..."
if dnf repolist enabled | grep -q "pgdg.*${PG_VERSION}" || \
   [ -f /etc/yum.repos.d/pgdg-redhat-all.repo ] || \
   [ -f /etc/yum.repos.d/pgdg-redhat.repo ]; then
    echo "PostgreSQL repository appears to be already installed."
else
    # Install PostgreSQL repository for Rocky Linux 8 (EL-8)
    echo "Installing PostgreSQL repository..."
    dnf install -y "${PG_REPO_URL}" || {
        echo "Error: Failed to install PostgreSQL repository"
        exit 1
    }
    echo "PostgreSQL repository installed successfully."
fi

# Refresh metadata after adding new repository
# This is critical - dnf needs to download metadata from the newly added repository
# before packages from that repository can be queried or installed
echo "Refreshing dnf metadata to include PostgreSQL repository..."
if dnf makecache; then
    echo "dnf metadata refreshed successfully."
else
    echo "Warning: dnf makecache encountered some issues after adding PostgreSQL repository"
    echo "Continuing anyway - package verification will confirm if repository is accessible"
fi

# Verify PostgreSQL packages are available
# Check by grepping output to ensure packages actually exist, not just that dnf can query repos
echo "Verifying PostgreSQL ${PG_VERSION} packages are available..."
PACKAGES_FOUND=false
if dnf list available ${PG_SERVER_PKG} ${PG_CONTRIB_PKG} 2>&1 | grep -q "${PG_SERVER_PKG}"; then
    if dnf list available ${PG_SERVER_PKG} ${PG_CONTRIB_PKG} 2>&1 | grep -q "${PG_CONTRIB_PKG}"; then
        PACKAGES_FOUND=true
    fi
fi

if [ "$PACKAGES_FOUND" = false ]; then
    echo "Error: PostgreSQL ${PG_VERSION} packages are not available in repositories"
    echo "Attempting to list available PostgreSQL packages..."
    # Use timeout to prevent hanging if dnf is slow
    timeout 30 dnf list available 2>&1 | grep -i postgresql || echo "No PostgreSQL packages found"
    exit 1
fi

echo "PostgreSQL ${PG_VERSION} packages are available. Proceeding with installation..."

# Install PostgreSQL packages
echo "Installing PostgreSQL ${PG_VERSION} server and contrib packages..."
dnf install -y ${PG_SERVER_PKG} ${PG_CONTRIB_PKG} || {
    echo "Error: Failed to install PostgreSQL ${PG_VERSION} packages"
    exit 1
}

# Verify packages were actually installed
echo "Verifying package installation..."
if ! rpm -q ${PG_SERVER_PKG} > /dev/null 2>&1; then
    echo "Error: ${PG_SERVER_PKG} was not installed correctly"
    exit 1
fi
if ! rpm -q ${PG_CONTRIB_PKG} > /dev/null 2>&1; then
    echo "Error: ${PG_CONTRIB_PKG} was not installed correctly"
    exit 1
fi
echo "Packages verified: ${PG_SERVER_PKG} and ${PG_CONTRIB_PKG} are installed"

# Verify systemd service file exists
echo "Verifying PostgreSQL service file..."
if [ ! -f "/usr/lib/systemd/system/${PG_SERVICE}.service" ]; then
    echo "Warning: PostgreSQL service file not found at /usr/lib/systemd/system/${PG_SERVICE}.service"
    echo "Service may not be available for management"
else
    echo "PostgreSQL service file found"
fi

# Initialize database (if not already initialized)
echo "Checking if PostgreSQL database needs initialization..."
if [ ! -d "${PG_DATA_DIR}" ]; then
    echo "Initializing PostgreSQL ${PG_VERSION} database..."
    if [ ! -f "${PG_SETUP_SCRIPT}" ]; then
        echo "Error: PostgreSQL setup script not found at ${PG_SETUP_SCRIPT}"
        exit 1
    fi
    if ! ${PG_SETUP_SCRIPT} initdb; then
        echo "Error: Failed to initialize PostgreSQL database"
        echo "Please check the PostgreSQL setup script and permissions"
        exit 1
    fi
    # Verify data directory was created and contains expected files
    if [ ! -d "${PG_DATA_DIR}" ]; then
        echo "Error: Database initialization reported success but data directory was not created"
        exit 1
    fi
    if [ ! -f "${PG_DATA_DIR}/postgresql.conf" ]; then
        echo "Error: Database initialization reported success but postgresql.conf was not created"
        exit 1
    fi
    echo "PostgreSQL database initialized successfully."
else
    echo "PostgreSQL database already initialized at ${PG_DATA_DIR}"
fi

echo "PostgreSQL ${PG_VERSION} installed successfully."

# Verify installation
echo "Verifying PostgreSQL installation..."
VERIFICATION_PASSED=true

# Check if psql is in PATH
if command -v psql &> /dev/null; then
    PSQL_VERSION=$(psql --version)
    echo "PostgreSQL client version: $PSQL_VERSION"
else
    echo "Warning: psql command not found in PATH"
    echo "Note: PostgreSQL may be installed but not in PATH. Check ${PG_BIN_DIR}/"
    VERIFICATION_PASSED=false
fi

# Verify PostgreSQL server binary exists and can report version
if [ -f "${PG_BIN_DIR}/postgres" ]; then
    POSTGRES_VERSION=$(${PG_BIN_DIR}/postgres --version 2>/dev/null || echo "unknown")
    if [ "$POSTGRES_VERSION" != "unknown" ]; then
        echo "PostgreSQL server binary found: $POSTGRES_VERSION"
    else
        echo "Warning: Could not determine PostgreSQL server version"
        VERIFICATION_PASSED=false
    fi
else
    echo "Warning: PostgreSQL server binary not found at ${PG_BIN_DIR}/postgres"
    VERIFICATION_PASSED=false
fi

# Verify psql binary exists even if not in PATH
if [ -f "${PG_BIN_DIR}/psql" ]; then
    PSQL_BIN_VERSION=$(${PG_BIN_DIR}/psql --version 2>/dev/null || echo "unknown")
    if [ "$PSQL_BIN_VERSION" != "unknown" ]; then
        echo "psql binary found at ${PG_BIN_DIR}/psql: $PSQL_BIN_VERSION"
    fi
fi

if [ "$VERIFICATION_PASSED" = false ]; then
    echo "Warning: Some verification checks failed, but installation may still be functional"
fi

echo "PostgreSQL installation completed successfully."
