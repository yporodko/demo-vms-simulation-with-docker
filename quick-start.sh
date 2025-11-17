#!/bin/bash

echo "=================================="
echo "Infrastructure Test - Quick Start"
echo "=================================="
echo ""

# Check if docker and docker-compose are installed
if ! command -v docker &> /dev/null; then
    echo "Error: Docker is not installed"
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    echo "Error: Docker Compose is not installed"
    exit 1
fi

echo "Step 1: Building all containers..."
docker-compose build

echo ""
echo "Step 2: Starting all services..."
docker-compose up -d

echo ""
echo "Step 3: Waiting for services to be ready..."
sleep 10

echo ""
echo "=================================="
echo "Services Status"
echo "=================================="
docker-compose ps

echo ""
echo "=================================="
echo "Quick Access Information"
echo "=================================="
echo ""
echo "SSH Access (password: testpass):"
echo "  maria-primary:      ssh -p 2201 testuser@localhost"
echo "  maria-replica:      ssh -p 2202 testuser@localhost"
echo "  postgres-primary:   ssh -p 2203 testuser@localhost"
echo "  nginx:              ssh -p 2209 testuser@localhost"
echo "  asterisk-balancer:  ssh -p 2212 testuser@localhost"
echo ""
echo "Database Access:"
echo "  MariaDB Primary:    mysql -h localhost -P 3306 -u app_user -p app_password"
echo "  MariaDB Replica:    mysql -h localhost -P 3307 -u app_user -p app_password"
echo "  PostgreSQL Primary: psql -h localhost -p 5432 -U postgres -d ecommerce"
echo "  PostgreSQL Load Bal: psql -h localhost -p 5435 -U postgres -d ecommerce"
echo ""
echo "Web Services:"
echo "  Nginx:              curl http://localhost:8000/"
echo "  HAProxy Stats:      http://localhost:8404/stats"
echo ""
echo "Asterisk Testing:"
echo "  docker exec -it sipp bash"
echo "  sipp -sn uac asterisk-balancer:5060 -m 10 -r 1"
echo ""
echo "View Logs:"
echo "  docker-compose logs -f [service-name]"
echo ""
echo "=================================="
echo "Setup Complete!"
echo "=================================="
