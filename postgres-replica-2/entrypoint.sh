#!/bin/bash
set -e

# Start SSH server
service ssh start

# PostgreSQL data directory
PGDATA="/var/lib/postgresql/9.6/main"

# Wait for primary to be ready
echo "Waiting for primary server..."
sleep 15

# Initialize PostgreSQL replica from primary if needed
if [ ! -f "$PGDATA/PG_VERSION" ]; then
    echo "Initializing PostgreSQL replica from primary..."
    mkdir -p "$PGDATA"
    chown -R postgres:postgres "$PGDATA"
    chmod 700 "$PGDATA"

    # Use pg_basebackup to clone from primary
    PGPASSWORD=app_password su - postgres -c "pg_basebackup -h postgres-primary -D $PGDATA -U postgres -v -P -X stream"
fi

# Copy recovery configuration
if [ -f "/config/recovery.conf" ]; then
    cp /config/recovery.conf "$PGDATA/recovery.conf"
    chown postgres:postgres "$PGDATA/recovery.conf"
fi

# Copy other config files
if [ -f "/config/pg_hba.conf" ]; then
    cp /config/pg_hba.conf "$PGDATA/pg_hba.conf"
fi

if [ -f "/config/postgresql-custom.conf" ]; then
    cat /config/postgresql-custom.conf >> "$PGDATA/postgresql.conf"
fi

chown postgres:postgres "$PGDATA"/*.conf 2>/dev/null || true

# Start PostgreSQL
su - postgres -c "/usr/lib/postgresql/9.6/bin/pg_ctl -D $PGDATA -l $PGDATA/logfile start"

echo "PostgreSQL Replica 2 is ready!"

# Keep container running
tail -f /dev/null
