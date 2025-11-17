#!/bin/bash
set -e

# Start SSH server
service ssh start

# Copy nginx configuration
if [ -f "/config/nginx.conf" ]; then
    cp /config/nginx.conf /etc/nginx/nginx.conf
fi

if [ -f "/config/default" ]; then
    cp /config/default /etc/nginx/sites-available/default
fi

# Test nginx configuration
nginx -t

# Wait for app servers to be ready
echo "Waiting for app servers..."
sleep 5

# Start nginx
service nginx start

echo "Nginx reverse proxy is ready!"

# Keep container running
tail -f /dev/null
