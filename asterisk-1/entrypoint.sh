#!/bin/bash
set -e

# Copy configuration files from /config to /etc/asterisk
if [ -d "/config" ]; then
    echo "Copying Asterisk configuration files..."
    cp /config/*.conf /etc/asterisk/ 2>/dev/null || true
fi

# Start Asterisk in foreground
echo "Starting Asterisk PBX 1..."
exec asterisk -f -vvv
