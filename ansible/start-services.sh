#!/bin/bash
# Helper script to start services in Docker containers after Ansible configuration
# This is needed because systemd doesn't work in basic Docker containers

set -e

INVENTORY="${1:-inventory/hosts-docker-test.yml}"
SERVICE="${2}"

echo "🚀 Starting services in Docker containers..."
echo ""

if [ -z "$SERVICE" ] || [ "$SERVICE" == "mariadb" ]; then
    echo "Starting MariaDB on maria-primary-test..."
    ansible maria-primary-test -i "$INVENTORY" -m shell -a "/usr/sbin/service mariadb start" 2>/dev/null || true

    if ansible mariadb -i "$INVENTORY" --list-hosts 2>/dev/null | grep -q maria-replica-test; then
        echo "Starting MariaDB on maria-replica-test..."
        ansible maria-replica-test -i "$INVENTORY" -m shell -a "/usr/sbin/service mariadb start" 2>/dev/null || true
    fi
fi

if [ -z "$SERVICE" ] || [ "$SERVICE" == "postgres" ] || [ "$SERVICE" == "postgresql" ]; then
    echo "Starting PostgreSQL on postgres-primary-test..."
    ansible postgres-primary-test -i "$INVENTORY" -m shell -a "cd /tmp && sudo -u postgres /usr/lib/postgresql/9.6/bin/pg_ctl -D /var/lib/postgresql/9.6/main -l /var/log/postgresql/postgresql-9.6-main.log start" 2>/dev/null || true
    sleep 2

    if ansible postgres -i "$INVENTORY" --list-hosts 2>/dev/null | grep -q postgres-replica-1-test; then
        echo "Starting PostgreSQL on postgres-replica-1-test..."
        ansible postgres-replica-1-test -i "$INVENTORY" -m shell -a "cd /tmp && sudo -u postgres /usr/lib/postgresql/9.6/bin/pg_ctl -D /var/lib/postgresql/9.6/main -l /var/log/postgresql/postgresql-9.6-main.log start" 2>/dev/null || true
    fi

    if ansible postgres -i "$INVENTORY" --list-hosts 2>/dev/null | grep -q postgres-replica-2-test; then
        echo "Starting PostgreSQL on postgres-replica-2-test..."
        ansible postgres-replica-2-test -i "$INVENTORY" -m shell -a "cd /tmp && sudo -u postgres /usr/lib/postgresql/9.6/bin/pg_ctl -D /var/lib/postgresql/9.6/main -l /var/log/postgresql/postgresql-9.6-main.log start" 2>/dev/null || true
    fi
fi

if [ -z "$SERVICE" ] || [ "$SERVICE" == "haproxy" ]; then
    echo "Starting HAProxy on postgres-primary-test..."
    ansible postgres-primary-test -i "$INVENTORY" -m shell -a "haproxy -f /etc/haproxy/haproxy.cfg -D 2>/dev/null || true" 2>/dev/null || true
fi

echo ""
echo "✅ Services started!"
echo ""
echo "Verify with:"
echo "  docker exec maria-primary-test service mariadb status"
echo "  docker exec postgres-primary-test sudo -u postgres psql -c 'SELECT 1;'"
echo "  docker exec postgres-primary-test curl -s http://localhost:8404/  # HAProxy stats"
