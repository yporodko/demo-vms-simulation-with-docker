#!/bin/bash
set -e

# Start SSH server
service ssh start

# Copy HAProxy configuration
if [ -f "/config/haproxy.cfg" ]; then
    cp /config/haproxy.cfg /etc/haproxy/haproxy.cfg
fi

# Wait for PostgreSQL servers to be ready
echo "Waiting for PostgreSQL servers to be ready..."
sleep 20

# Start HAProxy
service haproxy start

echo "HAProxy PostgreSQL Balancer is ready!"
echo "Stats available at http://localhost:8404/stats"

# Keep container running
tail -f /dev/null
