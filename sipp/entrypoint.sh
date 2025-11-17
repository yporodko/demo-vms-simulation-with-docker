#!/bin/bash
set -e

# Start SSH server
service ssh start

echo "SIPp testing tool is ready!"
echo "To run tests, execute: sipp -sn uac asterisk-balancer:5060 -m 10"

# Keep container running
tail -f /dev/null
