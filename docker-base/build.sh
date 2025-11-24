#!/bin/bash
set -e

echo "Building base Debian 12 image for VM simulation..."
echo ""

# Check if SSH key exists
SSH_KEY="$HOME/.ssh/redi_test_key.pub"
if [ ! -f "$SSH_KEY" ]; then
    echo "❌ Error: SSH public key not found at $SSH_KEY"
    echo "Please ensure the key exists before building the image."
    exit 1
fi

# Copy SSH public key to build context
echo "📋 Copying SSH public key to build context..."
cp "$SSH_KEY" ./redi_test_key.pub

# Build the image
echo "🔨 Building Docker image..."
docker build -t vm-base:debian12 .

# Clean up
echo "🧹 Cleaning up..."
rm -f ./redi_test_key.pub

echo ""
echo "✅ Base image built successfully: vm-base:debian12"
echo "   SSH key: $(basename $SSH_KEY) is pre-configured"
