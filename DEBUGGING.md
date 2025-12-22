# Debugging Connection Issues

## Problem
Frontend could not connect to backend. Backend service was failing to start.

## Environment
- Backend VM: `10.103.234.26:8080`
- Frontend VM: `10.103.234.4:3000`
- PostgreSQL VM: `10.103.234.6:5432`

## Debugging Steps

### 1. Checked Backend Service Status
```bash
systemctl status poll-app-backend
```
**Finding**: Service in `activating (auto-restart)` state, process exiting with status 1.

### 2. Examined Backend Logs
```bash
journalctl -u poll-app-backend -n 50
```
**Finding**: Error: `password authentication failed for user "postgres"`

### 3. Verified Network Connectivity
- ✅ Backend → PostgreSQL: Port 5432 reachable
- ✅ Frontend → Backend: Port 8080 reachable
- ✅ Firewall rules: All ports (8080, 3000, 5432) configured correctly

### 4. Checked PostgreSQL Configuration
- ✅ PostgreSQL service: Running
- ✅ `pg_hba.conf`: Configured for remote connections (`0.0.0.0/0`)
- ✅ Firewall: Port 5432 open
- ❌ **Password**: Not set to expected value `"postgres"`

### 5. Root Cause
PostgreSQL `postgres` user password was not set to `"postgres"` as expected by backend configuration.

## Solution

### Immediate Fix
```sql
ALTER USER postgres WITH PASSWORD 'postgres';
```

### Permanent Fix
Updated `calm/scripts/postgres/configure_postgres.sh` to explicitly set the password:
```bash
# Explicitly set password for postgres user
ALTER USER ${POSTGRES_USER} WITH PASSWORD '${POSTGRES_PASSWORD}';
```

## Verification

After fix:
- ✅ Backend service: Running and listening on port 8080
- ✅ Backend health endpoint: `http://10.103.234.26:8080/health` returns "We are Up!"
- ✅ Frontend → Backend: Connection successful
- ✅ Frontend service: Running and accessible

## Key Learnings

1. **Always verify service logs** when services fail to start
2. **Check authentication credentials** match between services
3. **Explicitly set passwords** in configuration scripts, don't assume defaults
4. **Network connectivity** (firewall, ports) was correctly configured - issue was authentication

