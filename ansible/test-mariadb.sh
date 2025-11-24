#!/bin/bash
# Unified test script for MariaDB replication setup
# Works for both Docker testing and production VMs
#
# Usage:
#   Docker:      ./test-mariadb.sh docker
#   Production:  ./test-mariadb.sh prod
#   Both:        ./test-mariadb.sh all

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test results tracking
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

print_header() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}\n"
}

print_test() {
    echo -e "${YELLOW}TEST:${NC} $1"
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
}

print_success() {
    echo -e "${GREEN}✓ PASS:${NC} $1"
    PASSED_TESTS=$((PASSED_TESTS + 1))
}

print_failure() {
    echo -e "${RED}✗ FAIL:${NC} $1"
    FAILED_TESTS=$((FAILED_TESTS + 1))
}

print_info() {
    echo -e "${BLUE}INFO:${NC} $1"
}

# Determine which environment to test
ENV="${1:-docker}"

if [ "$ENV" != "docker" ] && [ "$ENV" != "prod" ] && [ "$ENV" != "all" ]; then
    echo "Usage: $0 [docker|prod|all]"
    echo "  docker - Test Docker environment"
    echo "  prod   - Test production environment"
    echo "  all    - Test both environments"
    exit 1
fi

test_mariadb_environment() {
    local ENV_NAME="$1"
    local INVENTORY="$2"
    local PRIMARY_HOST="$3"
    local REPLICA_HOST="$4"

    print_header "Testing MariaDB Replication - $(echo ${ENV_NAME} | tr '[:lower:]' '[:upper:]') Environment"

    # Test 1: Check if primary is accessible
    print_test "Primary server connectivity"
    if ansible "$PRIMARY_HOST" -i "$INVENTORY" -m ping &>/dev/null; then
        print_success "Primary server is accessible"
    else
        print_failure "Cannot connect to primary server"
        return
    fi

    # Test 2: Check if replica is accessible
    print_test "Replica server connectivity"
    if ansible "$REPLICA_HOST" -i "$INVENTORY" -m ping &>/dev/null; then
        print_success "Replica server is accessible"
    else
        print_failure "Cannot connect to replica server"
        return
    fi

    # Test 3: Check MariaDB is running on primary
    print_test "MariaDB service status on primary"
    if ansible "$PRIMARY_HOST" -i "$INVENTORY" -m shell -a "mysql -V" &>/dev/null; then
        VERSION=$(ansible "$PRIMARY_HOST" -i "$INVENTORY" -m shell -a "mysql -V" 2>/dev/null | grep -o 'Distrib [0-9.]*' | awk '{print $2}')
        print_success "MariaDB is installed on primary (version: $VERSION)"
    else
        print_failure "MariaDB is not responding on primary"
    fi

    # Test 4: Check MariaDB is running on replica
    print_test "MariaDB service status on replica"
    if ansible "$REPLICA_HOST" -i "$INVENTORY" -m shell -a "mysql -V" &>/dev/null; then
        VERSION=$(ansible "$REPLICA_HOST" -i "$INVENTORY" -m shell -a "mysql -V" 2>/dev/null | grep -o 'Distrib [0-9.]*' | awk '{print $2}')
        print_success "MariaDB is installed on replica (version: $VERSION)"
    else
        print_failure "MariaDB is not responding on replica"
    fi

    # Test 5: Check primary server status
    print_test "Primary server binary logging"
    MASTER_STATUS=$(ansible "$PRIMARY_HOST" -i "$INVENTORY" -m shell -a "mysql -u root -e 'SHOW MASTER STATUS;'" 2>/dev/null | tail -n +2)
    if echo "$MASTER_STATUS" | grep -q "mysql-bin"; then
        BINLOG_FILE=$(echo "$MASTER_STATUS" | awk '{print $1}' | tail -1)
        BINLOG_POS=$(echo "$MASTER_STATUS" | awk '{print $2}' | tail -1)
        print_success "Binary logging is active (File: $BINLOG_FILE, Position: $BINLOG_POS)"
    else
        print_failure "Binary logging is not enabled on primary"
    fi

    # Test 6: Check replication status
    print_test "Replica IO thread status"
    SLAVE_IO=$(ansible "$REPLICA_HOST" -i "$INVENTORY" -m shell -a "mysql -u root -e 'SHOW SLAVE STATUS\G' | grep 'Slave_IO_Running:'" 2>/dev/null | tail -1 | awk '{print $2}')
    if [ "$SLAVE_IO" == "Yes" ]; then
        print_success "Replica IO thread is running"
    else
        print_failure "Replica IO thread is NOT running (Status: $SLAVE_IO)"
    fi

    # Test 7: Check SQL thread
    print_test "Replica SQL thread status"
    SLAVE_SQL=$(ansible "$REPLICA_HOST" -i "$INVENTORY" -m shell -a "mysql -u root -e 'SHOW SLAVE STATUS\G' | grep 'Slave_SQL_Running:'" 2>/dev/null | tail -1 | awk '{print $2}')
    if [ "$SLAVE_SQL" == "Yes" ]; then
        print_success "Replica SQL thread is running"
    else
        print_failure "Replica SQL thread is NOT running (Status: $SLAVE_SQL)"
    fi

    # Test 8: Check replication lag
    print_test "Replication lag check"
    SECONDS_BEHIND=$(ansible "$REPLICA_HOST" -i "$INVENTORY" -m shell -a "mysql -u root -e 'SHOW SLAVE STATUS\G' | grep 'Seconds_Behind_Master:'" 2>/dev/null | tail -1 | awk '{print $2}')
    if [ "$SECONDS_BEHIND" == "0" ]; then
        print_success "No replication lag (0 seconds behind)"
    elif [ "$SECONDS_BEHIND" == "NULL" ]; then
        print_failure "Replication lag is NULL (replication may be broken)"
    else
        print_info "Replication lag: $SECONDS_BEHIND seconds"
    fi

    # Test 9: Check database exists
    print_test "Database existence check"
    if ansible "$PRIMARY_HOST" -i "$INVENTORY" -m shell -a "mysql -u root -e 'SHOW DATABASES;' | grep voip_db" &>/dev/null; then
        print_success "Database 'voip_db' exists on primary"
    else
        print_failure "Database 'voip_db' not found on primary"
    fi

    # Test 10: Check application user exists
    print_test "Application user connectivity"
    if ansible "$PRIMARY_HOST" -i "$INVENTORY" -m shell -a "mysql -u app_user -papp_password -e 'SELECT 1;'" &>/dev/null; then
        print_success "Application user 'app_user' can connect to primary"
    else
        print_failure "Application user 'app_user' cannot connect to primary"
    fi

    # Test 11: Test data replication
    print_test "Data replication test"
    TEST_VALUE="test_$(date +%s)"

    # Drop and recreate test table to ensure clean state
    ansible "$PRIMARY_HOST" -i "$INVENTORY" -m shell -a "mysql -u root voip_db -e 'DROP TABLE IF EXISTS replication_test;'" -o &>/dev/null

    # Create test table
    if ansible "$PRIMARY_HOST" -i "$INVENTORY" -m shell -a "mysql -u root voip_db -e 'CREATE TABLE replication_test (id INT AUTO_INCREMENT PRIMARY KEY, test_data VARCHAR(100), created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP);'" -o &>/dev/null; then
        # Insert test data on primary
        if ansible "$PRIMARY_HOST" -i "$INVENTORY" -m shell -a "mysql -u root voip_db -e \"INSERT INTO replication_test (test_data) VALUES ('$TEST_VALUE');\"" -o &>/dev/null; then
            # Wait a moment for replication
            sleep 2

            # Check if data exists on replica
            if ansible "$REPLICA_HOST" -i "$INVENTORY" -m shell -a "mysql -u root voip_db -e \"SELECT * FROM replication_test WHERE test_data='$TEST_VALUE';\"" -o 2>/dev/null | grep -q "$TEST_VALUE"; then
                print_success "Data successfully replicated from primary to replica"
            else
                print_failure "Data did NOT replicate from primary to replica"
            fi
        else
            print_failure "Could not insert test data on primary"
        fi
    else
        print_failure "Could not create test table on primary"
    fi

    # Test 12: Test read-only protection on replica
    print_test "Read-only protection on replica"
    if ansible "$REPLICA_HOST" -i "$INVENTORY" -m shell -a "mysql -u app_user -papp_password voip_db -e 'INSERT INTO replication_test (test_data) VALUES (\"should_fail\");'" &>/dev/null; then
        print_failure "Replica allowed write operation (should be read-only)"
    else
        print_success "Replica correctly blocked write operation (read-only mode active)"
    fi

    # Test 13: Check server IDs are different
    print_test "Server ID uniqueness check"
    PRIMARY_ID=$(ansible "$PRIMARY_HOST" -i "$INVENTORY" -m shell -a "mysql -u root -e 'SHOW VARIABLES LIKE \"server_id\";'" 2>/dev/null | tail -1 | awk '{print $2}')
    REPLICA_ID=$(ansible "$REPLICA_HOST" -i "$INVENTORY" -m shell -a "mysql -u root -e 'SHOW VARIABLES LIKE \"server_id\";'" 2>/dev/null | tail -1 | awk '{print $2}')

    if [ "$PRIMARY_ID" != "$REPLICA_ID" ] && [ -n "$PRIMARY_ID" ] && [ -n "$REPLICA_ID" ]; then
        print_success "Server IDs are unique (Primary: $PRIMARY_ID, Replica: $REPLICA_ID)"
    else
        print_failure "Server IDs conflict or invalid (Primary: $PRIMARY_ID, Replica: $REPLICA_ID)"
    fi
}

# Main execution
if [ "$ENV" == "docker" ] || [ "$ENV" == "all" ]; then
    test_mariadb_environment "docker" "inventory/hosts-docker-test.yml" "maria-primary-test" "maria-replica-test"
fi

if [ "$ENV" == "prod" ] || [ "$ENV" == "all" ]; then
    test_mariadb_environment "production" "inventory/hosts.yml" "maria-primary" "maria-replica"
fi

# Print summary
print_header "Test Summary"
echo -e "Total Tests:  ${BLUE}${TOTAL_TESTS}${NC}"
echo -e "Passed:       ${GREEN}${PASSED_TESTS}${NC}"
echo -e "Failed:       ${RED}${FAILED_TESTS}${NC}"

if [ $FAILED_TESTS -eq 0 ]; then
    echo -e "\n${GREEN}✓ All tests passed!${NC}\n"
    exit 0
else
    echo -e "\n${RED}✗ Some tests failed!${NC}\n"
    exit 1
fi
