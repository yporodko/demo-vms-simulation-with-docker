#!/bin/bash
# Quick start script for testing Ansible playbooks on Docker containers

set -e

echo "🐳 Docker Testing Environment for Ansible"
echo "==========================================="
echo ""

# Function to wait for container to be ready
wait_for_container() {
    local container_name=$1
    echo "⏳ Waiting for $container_name to be ready..."
    sleep 2
    docker exec "$container_name" bash -c "systemctl is-system-running --wait 2>/dev/null || true" > /dev/null 2>&1 || true
}

# Function to clean SSH known_hosts for a port
clean_known_hosts() {
    local port=$1
    ssh-keygen -R "[localhost]:$port" 2>&1 | grep -v "^#" || true
}

case "${1:-help}" in
    start)
        echo "📦 Starting Docker containers..."
        docker-compose up -d maria-primary-test maria-replica-test
        echo "✅ Containers started"
        echo ""

        echo "⏳ Waiting for containers to be ready..."
        wait_for_container maria-primary-test
        wait_for_container maria-replica-test
        echo ""

        echo "🔧 Cleaning SSH known_hosts..."
        clean_known_hosts 2201
        clean_known_hosts 2202
        echo "✅ SSH ready (keys pre-configured in image)"
        echo ""

        echo "🧪 Testing Ansible connectivity..."
        cd ansible && ansible -i inventory/hosts-docker-test.yml mariadb -m ping
        echo ""
        echo "✅ Ready! Run './test-docker.sh deploy' to test deployment"
        ;;

    deploy)
        echo "🚀 Deploying MariaDB replication to Docker..."
        echo ""
        echo "Step 1: Deploying maria-primary..."
        cd ansible && ansible-playbook -i inventory/hosts-docker-test.yml playbooks/maria-primary-test.yml
        echo ""
        echo "Step 2: Starting MariaDB service on maria-primary..."
        ./start-services.sh inventory/hosts-docker-test.yml mariadb
        echo ""
        echo "Step 3: Deploying maria-replica..."
        ansible-playbook -i inventory/hosts-docker-test.yml playbooks/maria-replica-test.yml
        echo ""
        echo "Step 4: Starting MariaDB service on maria-replica..."
        ./start-services.sh inventory/hosts-docker-test.yml mariadb
        echo ""
        echo "✅ Deployment complete! Test replication with:"
        echo "   ./test-docker.sh test-replication"
        ;;

    stop)
        echo "🛑 Stopping Docker containers..."
        docker-compose down
        echo "✅ Containers stopped"
        ;;

    clean)
        echo "🧹 Cleaning up Docker containers and volumes..."
        docker-compose down -v
        echo "✅ Cleaned up"
        ;;

    status)
        echo "📊 Docker container status:"
        docker-compose ps
        ;;

    logs)
        container="${2:-maria-primary-test}"
        echo "📋 Showing logs for $container:"
        docker logs "$container" --tail 50
        ;;

    ssh)
        container="${2:-maria-primary-test}"
        port=$(docker-compose port "$container" 22 | cut -d: -f2)
        echo "🔐 Connecting to $container on port $port..."
        ssh -i ~/.ssh/redi_test_key -o StrictHostKeyChecking=no -p "$port" root@localhost
        ;;

    test-replication)
        echo "🧪 Testing MariaDB Replication..."
        echo ""
        echo "1. Inserting test data on primary..."
        docker exec maria-primary-test mysql -u root voip_db -e "
            DROP TABLE IF EXISTS replication_test;
            CREATE TABLE replication_test (
                id INT AUTO_INCREMENT PRIMARY KEY,
                message VARCHAR(255),
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            );
            INSERT INTO replication_test (message) VALUES
                ('Message 1 - from primary'),
                ('Message 2 - replication test'),
                ('Message 3 - this is working!');
        "

        echo "2. Waiting for replication (2 seconds)..."
        sleep 2

        echo "3. Checking replica status..."
        docker exec maria-replica-test mysql -u root -e "SHOW SLAVE STATUS\G" | grep -E "(Slave_.*_Running|Seconds_Behind_Master|Last_Error)" | grep -v "Last_Error: $"

        echo ""
        echo "4. Verifying data on primary:"
        docker exec maria-primary-test mysql -u root voip_db -e "SELECT * FROM replication_test;"

        echo ""
        echo "5. Verifying data on replica:"
        docker exec maria-replica-test mysql -u root voip_db -e "SELECT * FROM replication_test;"

        echo ""
        echo "6. Testing read-only protection..."
        docker exec maria-replica-test mysql -u app_user -papp_password voip_db -e "INSERT INTO replication_test (message) VALUES ('This should fail');" 2>&1 | grep -i error && echo "✅ Read-only protection is working!" || echo "❌ Warning: Replica is writable!"

        echo ""
        echo "✅ Replication test complete!"
        ;;

    rebuild)
        echo "🔨 Rebuilding base Docker image..."
        cd docker-base && ./build.sh
        echo "✅ Base image rebuilt"
        echo "Run './test-docker.sh clean && ./test-docker.sh start' to recreate containers"
        ;;

    help|*)
        echo "Usage: ./test-docker.sh <command>"
        echo ""
        echo "Commands:"
        echo "  start              - Start Docker containers and configure SSH"
        echo "  deploy             - Deploy MariaDB primary and replica using Ansible"
        echo "  test-replication   - Test MariaDB replication between containers"
        echo "  stop               - Stop Docker containers"
        echo "  clean              - Stop containers and remove volumes"
        echo "  status             - Show container status"
        echo "  logs               - Show container logs (default: maria-primary-test)"
        echo "  ssh                - SSH into container (default: maria-primary-test)"
        echo "  rebuild            - Rebuild base Docker image"
        echo "  help               - Show this help message"
        echo ""
        echo "Examples:"
        echo "  ./test-docker.sh start              # Start containers"
        echo "  ./test-docker.sh deploy             # Deploy with Ansible"
        echo "  ./test-docker.sh test-replication   # Test replication"
        echo "  ./test-docker.sh ssh maria-replica-test   # SSH to replica"
        echo "  ./test-docker.sh logs maria-primary-test  # View logs"
        ;;
esac
