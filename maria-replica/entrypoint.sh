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

# Wait for primary to be ready
echo "Waiting for primary server to be ready..."
sleep 15

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

# Configure replication
echo "Configuring replication..."
mysql -u root <<-EOSQL
    -- Stop slave if running
    STOP SLAVE;

    -- Configure replication
    CHANGE MASTER TO
        MASTER_HOST='maria-primary',
        MASTER_USER='repl',
        MASTER_PASSWORD='replpass',
        MASTER_LOG_FILE='mysql-bin.000001',
        MASTER_LOG_POS=4;

    -- Start slave
    START SLAVE;

    -- Create application user (both for remote and local connections)
    -- On replica, grant only read privileges
    -- Drop and recreate to ensure correct privileges even if user was replicated
    DROP USER IF EXISTS 'app_user'@'%';
    DROP USER IF EXISTS 'app_user'@'localhost';
    CREATE USER 'app_user'@'%' IDENTIFIED BY 'app_password';
    GRANT SELECT ON *.* TO 'app_user'@'%';

    CREATE USER 'app_user'@'localhost' IDENTIFIED BY 'app_password';
    GRANT SELECT ON *.* TO 'app_user'@'localhost';

    FLUSH PRIVILEGES;
EOSQL

echo "MariaDB Replica is ready!"

# Keep container running
tail -f /dev/null
