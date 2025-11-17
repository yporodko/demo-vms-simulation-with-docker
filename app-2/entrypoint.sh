#!/bin/bash
set -e

# Start SSH server
service ssh start

# Create a simple web application
mkdir -p /var/www/html
cat > /var/www/html/index.html <<'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>App Server 2</title>
</head>
<body>
    <h1>Response from App Server 2</h1>
    <p>This is the backend application server 2.</p>
    <p>Server: app-2 (172.20.0.31)</p>
</body>
</html>
EOF

# Start a simple HTTP server on port 80
cd /var/www/html
python3 -m http.server 80 &

echo "App Server 2 is ready!"

# Keep container running
tail -f /dev/null
