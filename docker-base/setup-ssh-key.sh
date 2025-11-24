#!/bin/bash
set -e

# Script to add SSH public key to a running container

CONTAINER_NAME=${1:-maria-primary}
SSH_PUBLIC_KEY_PATH=${2:-~/.ssh/redi_test_key.pub}

# Expand tilde
SSH_PUBLIC_KEY_PATH="${SSH_PUBLIC_KEY_PATH/#\~/$HOME}"

if [ ! -f "$SSH_PUBLIC_KEY_PATH" ]; then
    echo "ERROR: SSH public key not found at: $SSH_PUBLIC_KEY_PATH"
    exit 1
fi

echo "Adding SSH key to container: $CONTAINER_NAME"

# Copy public key into container
docker exec "$CONTAINER_NAME" bash -c "
    mkdir -p /root/.ssh
    chmod 700 /root/.ssh
    echo '$(cat "$SSH_PUBLIC_KEY_PATH")' >> /root/.ssh/authorized_keys
    chmod 600 /root/.ssh/authorized_keys
    echo 'SSH key added successfully'
"

echo "✓ SSH key configured for root user in $CONTAINER_NAME"
echo "Test connection: ssh -i ${SSH_PUBLIC_KEY_PATH%.pub} -p <port> root@localhost"
