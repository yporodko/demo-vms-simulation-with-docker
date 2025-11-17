#!/bin/bash
set -e

# Start SSH server
service ssh start

# Copy Kamailio configuration
if [ -f "/config/kamailio.cfg" ]; then
    cp /config/kamailio.cfg /etc/kamailio/kamailio.cfg
fi

if [ -f "/config/dispatcher.list" ]; then
    cp /config/dispatcher.list /etc/kamailio/dispatcher.list
fi

# Wait for Asterisk servers to be ready
echo "Waiting for Asterisk servers..."
sleep 10

# Start Kamailio
echo "Starting Kamailio SIP load balancer..."
kamailio -DD -E &

echo "Kamailio is ready!"

# Keep container running
tail -f /dev/null
