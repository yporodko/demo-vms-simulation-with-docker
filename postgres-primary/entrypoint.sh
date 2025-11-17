#!/bin/bash
set -e

# Start SSH server
service ssh start

# PostgreSQL data directory
PGDATA="/var/lib/postgresql/9.6/main"

# Initialize PostgreSQL if needed
if [ ! -f "$PGDATA/PG_VERSION" ]; then
    echo "Initializing PostgreSQL data directory..."
    mkdir -p "$PGDATA"
    chown -R postgres:postgres "$PGDATA"
    chmod 700 "$PGDATA"
    su - postgres -c "/usr/lib/postgresql/9.6/bin/initdb -D $PGDATA"
fi

# Copy configuration files
if [ -f "/config/pg_hba.conf" ]; then
    cp /config/pg_hba.conf "$PGDATA/pg_hba.conf"
fi

if [ -f "/config/postgresql-custom.conf" ]; then
    cat /config/postgresql-custom.conf >> "$PGDATA/postgresql.conf"
fi

chown postgres:postgres "$PGDATA"/*.conf 2>/dev/null || true

# Start PostgreSQL
su - postgres -c "/usr/lib/postgresql/9.6/bin/pg_ctl -D $PGDATA -l $PGDATA/logfile start"

# Wait for PostgreSQL to be ready
until su - postgres -c "psql -c 'SELECT 1'" &>/dev/null; do
    echo "Waiting for PostgreSQL to start..."
    sleep 2
done

# Create database and users
su - postgres <<-EOSQL
    psql -c "CREATE DATABASE ecommerce;" || true
    psql -c "CREATE USER app_user WITH PASSWORD 'app_password';" || true
    psql -c "GRANT ALL PRIVILEGES ON DATABASE ecommerce TO app_user;" || true
    psql -c "CREATE USER replicator WITH REPLICATION LOGIN PASSWORD 'replicator_password';" || true
EOSQL

echo "PostgreSQL Primary is ready!"

# Keep container running
tail -f /dev/null
