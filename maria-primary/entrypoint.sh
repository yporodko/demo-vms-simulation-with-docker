#!/bin/bash
set -e

# Start SSH server
service ssh start

# Run MariaDB configuration script
/tmp/maria-configure.sh

echo "MariaDB Primary is ready!"

# Keep container running
tail -f /dev/null
