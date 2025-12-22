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
# Use --assumeyes to automatically accept GPG key imports
echo "Refreshing dnf metadata to include PostgreSQL repository..."
if dnf makecache --assumeyes; then
    echo "dnf metadata refreshed successfully."
else
    echo "Warning: dnf makecache encountered some issues after adding PostgreSQL repository"
    echo "Continuing anyway - package verification will confirm if repository is accessible"
fi

# Disable default PostgreSQL module to prevent conflicts with PGDG repository
echo "Disabling default PostgreSQL module..."
dnf module disable -y postgresql 2>/dev/null || {
    echo "Warning: Could not disable postgresql module (may not exist)"
}

# Install PostgreSQL packages
echo "Installing PostgreSQL ${PG_VERSION} server and contrib packages..."
dnf install -y ${PG_SERVER_PKG} ${PG_CONTRIB_PKG} || {
    echo "Error: Failed to install PostgreSQL ${PG_VERSION} packages"
    exit 1
}

# Verify packages were installed
if ! rpm -q ${PG_SERVER_PKG} ${PG_CONTRIB_PKG} > /dev/null 2>&1; then
    echo "Error: Packages were not installed correctly"
    exit 1
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
    # Verify data directory was created
    if [ ! -d "${PG_DATA_DIR}" ]; then
        echo "Error: Database initialization failed - data directory not created"
        exit 1
    fi
    echo "PostgreSQL database initialized successfully."
else
    echo "PostgreSQL database already initialized at ${PG_DATA_DIR}"
fi

echo "PostgreSQL ${PG_VERSION} installed successfully."

# Verify installation
if [ ! -f "${PG_BIN_DIR}/postgres" ]; then
    echo "Error: PostgreSQL server binary not found"
    exit 1
fi

echo "PostgreSQL installation completed successfully."
