#!/bin/bash
set -e

# Start SSH server
service ssh start

# Create log directory for MariaDB
mkdir -p /var/log/mysql
chown mysql:mysql /var/log/mysql

# Initialize MariaDB data directory if needed
if [ ! -d "/var/lib/mysql/mysql" ]; then
    echo "Initializing MariaDB data directory..."
    mysql_install_db --user=mysql --datadir=/var/lib/mysql
fi

# Start MariaDB in background
echo "Starting MariaDB..."
mysqld_safe --user=mysql &

# Wait for MariaDB to be ready
echo "Waiting for MariaDB to start..."
for i in {1..30}; do
    if mysqladmin ping -h localhost --silent 2>/dev/null; then
        echo "MariaDB is ready!"
        break
    fi
    sleep 1
done

# Configure database and users
echo "Configuring MariaDB..."
mysql -u root <<-EOSQL
    -- Create replication user
    CREATE USER IF NOT EXISTS 'repl'@'%' IDENTIFIED BY 'replpass';
    GRANT REPLICATION SLAVE ON *.* TO 'repl'@'%';

    -- Create application user (both for remote and local connections)
    CREATE USER IF NOT EXISTS 'app_user'@'%' IDENTIFIED BY 'app_password';
    GRANT ALL PRIVILEGES ON *.* TO 'app_user'@'%';

    CREATE USER IF NOT EXISTS 'app_user'@'localhost' IDENTIFIED BY 'app_password';
    GRANT ALL PRIVILEGES ON *.* TO 'app_user'@'localhost';

    -- Create database
    CREATE DATABASE IF NOT EXISTS voip_db;

    FLUSH PRIVILEGES;
EOSQL

# Initialize database from SQL file if it exists
if [ -f "/docker-init/voip_db.sql" ]; then
    echo "Loading initial data..."
    mysql -u root voip_db < /docker-init/voip_db.sql 2>/dev/null || true
fi

echo "MariaDB Primary is ready!"

# Keep container running
tail -f /dev/null
