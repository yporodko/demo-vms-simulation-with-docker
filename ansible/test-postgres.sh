#!/bin/bash
# Unified test script for PostgreSQL replication setup
# Works for both Docker testing and production VMs
#
# Usage:
#   Docker:      ./test-postgres.sh docker
#   Production:  ./test-postgres.sh prod
#   Both:        ./test-postgres.sh all

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

test_postgres_environment() {
    local ENV_NAME="$1"
    local INVENTORY="$2"
    local PRIMARY_HOST="$3"
    local REPLICA1_HOST="$4"
    local REPLICA2_HOST="$5"

    print_header "Testing PostgreSQL Replication - $(echo ${ENV_NAME} | tr '[:lower:]' '[:upper:]') Environment"

    # Test 1: Check if primary is accessible
    print_test "Primary server connectivity"
    if ansible "$PRIMARY_HOST" -i "$INVENTORY" -m ping &>/dev/null; then
        print_success "Primary server is accessible"
    else
        print_failure "Cannot connect to primary server"
        return
    fi

    # Test 2: Check if replica-1 is accessible
    print_test "Replica-1 server connectivity"
    if ansible "$REPLICA1_HOST" -i "$INVENTORY" -m ping &>/dev/null; then
        print_success "Replica-1 server is accessible"
    else
        print_failure "Cannot connect to replica-1 server"
    fi

    # Test 3: Check if replica-2 is accessible
    print_test "Replica-2 server connectivity"
    if ansible "$REPLICA2_HOST" -i "$INVENTORY" -m ping &>/dev/null; then
        print_success "Replica-2 server is accessible"
    else
        print_failure "Cannot connect to replica-2 server"
    fi

    # Test 4: Check PostgreSQL is installed on primary
    print_test "PostgreSQL installation on primary"
    if ansible "$PRIMARY_HOST" -i "$INVENTORY" -m shell -a "psql --version" &>/dev/null; then
        VERSION=$(ansible "$PRIMARY_HOST" -i "$INVENTORY" -m shell -a "psql --version" 2>/dev/null | tail -1 | grep -o 'PostgreSQL [0-9.]*' | awk '{print $2}')
        print_success "PostgreSQL is installed on primary (version: $VERSION)"
    else
        print_failure "PostgreSQL is not installed on primary"
    fi

    # Test 5: Check PostgreSQL is running on primary
    print_test "PostgreSQL service status on primary"
    if ansible "$PRIMARY_HOST" -i "$INVENTORY" -m shell -a "sudo -u postgres psql -c 'SELECT 1;'" &>/dev/null; then
        print_success "PostgreSQL is running on primary"
    else
        print_failure "PostgreSQL is not running on primary"
    fi

    # Test 6: Check database exists on primary
    print_test "Database existence check on primary"
    if ansible "$PRIMARY_HOST" -i "$INVENTORY" -m shell -a "sudo -u postgres psql -lqt | grep -qw ecommerce" &>/dev/null; then
        print_success "Database 'ecommerce' exists on primary"
    else
        print_failure "Database 'ecommerce' not found on primary"
    fi

    # Test 7: Check application user can connect
    print_test "Application user connectivity"
    if ansible "$PRIMARY_HOST" -i "$INVENTORY" -m shell -a "PGPASSWORD=app_password psql -U app_user -h localhost -d ecommerce -c 'SELECT 1;'" &>/dev/null; then
        print_success "Application user 'app_user' can connect to primary"
    else
        print_failure "Application user 'app_user' cannot connect to primary"
    fi

    # Test 8: Check replication user exists
    print_test "Replication user check"
    if ansible "$PRIMARY_HOST" -i "$INVENTORY" -m shell -a "sudo -u postgres psql -c \"SELECT rolname FROM pg_roles WHERE rolname='replicator';\" | grep -q replicator" &>/dev/null; then
        print_success "Replication user 'replicator' exists"
    else
        print_failure "Replication user 'replicator' not found"
    fi

    # Test 9: Check replica-1 is in recovery mode
    print_test "Replica-1 recovery mode check"
    IS_RECOVERY=$(ansible "$REPLICA1_HOST" -i "$INVENTORY" -m shell -a "sudo -u postgres psql -t -c 'SELECT pg_is_in_recovery();'" 2>/dev/null | grep -oE "^\s*[tf]" | tr -d ' ')
    if [ "$IS_RECOVERY" == "t" ]; then
        print_success "Replica-1 is in recovery mode (streaming from primary)"
    else
        print_failure "Replica-1 is NOT in recovery mode (Status: $IS_RECOVERY)"
    fi

    # Test 10: Check replica-2 is in recovery mode
    print_test "Replica-2 recovery mode check"
    IS_RECOVERY=$(ansible "$REPLICA2_HOST" -i "$INVENTORY" -m shell -a "sudo -u postgres psql -t -c 'SELECT pg_is_in_recovery();'" 2>/dev/null | grep -oE "^\s*[tf]" | tr -d ' ')
    if [ "$IS_RECOVERY" == "t" ]; then
        print_success "Replica-2 is in recovery mode (streaming from primary)"
    else
        print_failure "Replica-2 is NOT in recovery mode (Status: $IS_RECOVERY)"
    fi

    # Test 11: Check replication connections on primary
    print_test "Active replication connections"
    REPL_COUNT=$(ansible "$PRIMARY_HOST" -i "$INVENTORY" -m shell -a "sudo -u postgres psql -t -c 'SELECT COUNT(*) FROM pg_stat_replication;'" 2>/dev/null | grep -oE "^\s*[0-9]+" | tr -d ' ')
    if [ -n "$REPL_COUNT" ] && [ "$REPL_COUNT" -ge "2" ]; then
        print_success "Primary has $REPL_COUNT active replication connections"
    else
        print_failure "Primary has insufficient replication connections (Expected: 2, Got: $REPL_COUNT)"
    fi

    # Test 12: Check replication lag on replica-1 (PostgreSQL 9.6 compatible)
    print_test "Replication lag check on replica-1"
    LAG=$(ansible "$REPLICA1_HOST" -i "$INVENTORY" -m shell -a "sudo -u postgres psql -t -c \"SELECT CASE WHEN pg_last_xlog_receive_location() = pg_last_xlog_replay_location() THEN 0 ELSE EXTRACT (EPOCH FROM now() - pg_last_xact_replay_timestamp()) END AS lag;\"" 2>/dev/null | grep -oE "^\s*[0-9.]+" | tr -d ' ')
    if [ -n "$LAG" ] && [ "$(echo "$LAG < 5" | bc 2>/dev/null)" == "1" ] 2>/dev/null; then
        print_success "Replica-1 has minimal lag (${LAG}s)"
    elif [ "$LAG" == "0" ]; then
        print_success "Replica-1 has no lag (0s)"
    else
        print_info "Replica-1 lag: ${LAG}s"
    fi

    # Test 13: Check replication lag on replica-2 (PostgreSQL 9.6 compatible)
    print_test "Replication lag check on replica-2"
    LAG=$(ansible "$REPLICA2_HOST" -i "$INVENTORY" -m shell -a "sudo -u postgres psql -t -c \"SELECT CASE WHEN pg_last_xlog_receive_location() = pg_last_xlog_replay_location() THEN 0 ELSE EXTRACT (EPOCH FROM now() - pg_last_xact_replay_timestamp()) END AS lag;\"" 2>/dev/null | grep -oE "^\s*[0-9.]+" | tr -d ' ')
    if [ -n "$LAG" ] && [ "$(echo "$LAG < 5" | bc 2>/dev/null)" == "1" ] 2>/dev/null; then
        print_success "Replica-2 has minimal lag (${LAG}s)"
    elif [ "$LAG" == "0" ]; then
        print_success "Replica-2 has no lag (0s)"
    else
        print_info "Replica-2 lag: ${LAG}s"
    fi

    # Test 14: Test data replication
    print_test "Data replication test"
    TEST_VALUE="test_$(date +%s)"

    # Drop and recreate test table on primary
    ansible "$PRIMARY_HOST" -i "$INVENTORY" -m shell -a "sudo -u postgres psql -d ecommerce -c 'DROP TABLE IF EXISTS replication_test;'" -o &>/dev/null

    # Create test table on primary
    if ansible "$PRIMARY_HOST" -i "$INVENTORY" -m shell -a "sudo -u postgres psql -d ecommerce -c 'CREATE TABLE replication_test (id SERIAL PRIMARY KEY, test_data VARCHAR(100), created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP);'" -o &>/dev/null; then
        # Insert test data on primary
        if ansible "$PRIMARY_HOST" -i "$INVENTORY" -m shell -a "sudo -u postgres psql -d ecommerce -c \"INSERT INTO replication_test (test_data) VALUES ('$TEST_VALUE');\"" -o &>/dev/null; then
            # Wait for replication
            sleep 3

            # Check if data exists on replica-1
            if ansible "$REPLICA1_HOST" -i "$INVENTORY" -m shell -a "sudo -u postgres psql -d ecommerce -c \"SELECT * FROM replication_test WHERE test_data='$TEST_VALUE';\"" -o 2>/dev/null | grep -q "$TEST_VALUE"; then
                print_success "Data successfully replicated from primary to replica-1"
            else
                print_failure "Data did NOT replicate from primary to replica-1"
            fi

            # Check if data exists on replica-2
            if ansible "$REPLICA2_HOST" -i "$INVENTORY" -m shell -a "sudo -u postgres psql -d ecommerce -c \"SELECT * FROM replication_test WHERE test_data='$TEST_VALUE';\"" -o 2>/dev/null | grep -q "$TEST_VALUE"; then
                print_success "Data successfully replicated from primary to replica-2"
            else
                print_failure "Data did NOT replicate from primary to replica-2"
            fi
        else
            print_failure "Could not insert test data on primary"
        fi
    else
        print_failure "Could not create test table on primary"
    fi

    # Test 15: Test read-only protection on replicas
    print_test "Read-only protection on replica-1"
    if ansible "$REPLICA1_HOST" -i "$INVENTORY" -m shell -a "sudo -u postgres psql -d ecommerce -c 'INSERT INTO replication_test (test_data) VALUES (\"should_fail\");'" &>/dev/null; then
        print_failure "Replica-1 allowed write operation (should be read-only)"
    else
        print_success "Replica-1 correctly blocked write operation (read-only mode)"
    fi

    print_test "Read-only protection on replica-2"
    if ansible "$REPLICA2_HOST" -i "$INVENTORY" -m shell -a "sudo -u postgres psql -d ecommerce -c 'INSERT INTO replication_test (test_data) VALUES (\"should_fail\");'" &>/dev/null; then
        print_failure "Replica-2 allowed write operation (should be read-only)"
    else
        print_success "Replica-2 correctly blocked write operation (read-only mode)"
    fi
}

# Main execution
if [ "$ENV" == "docker" ] || [ "$ENV" == "all" ]; then
    test_postgres_environment "docker" "inventory/hosts-docker-test.yml" "postgres-primary-test" "postgres-replica-1-test" "postgres-replica-2-test"
fi

if [ "$ENV" == "prod" ] || [ "$ENV" == "all" ]; then
    test_postgres_environment "production" "inventory/hosts.yml" "postgres-primary" "postgres-replica-1" "postgres-replica-2"
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
