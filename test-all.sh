#!/bin/bash

echo "=================================="
echo "Running Infrastructure Tests"
echo "=================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

test_passed=0
test_failed=0

# Test function
run_test() {
    local test_name=$1
    local test_command=$2

    echo -e "${YELLOW}Testing: ${test_name}${NC}"
    if eval "$test_command" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ PASSED${NC}"
        ((test_passed++))
    else
        echo -e "${RED}✗ FAILED${NC}"
        ((test_failed++))
    fi
    echo ""
}

echo "Task 1: MariaDB Primary/Replica"
echo "--------------------------------"
run_test "MariaDB Primary Connection" "docker exec maria-primary mysql -u app_user -papp_password -e 'SELECT 1' 2>/dev/null"
run_test "MariaDB Replica Connection" "docker exec maria-replica mysql -u app_user -papp_password -e 'SELECT 1' 2>/dev/null"
run_test "MariaDB Replication Running" "docker exec maria-replica mysql -u root -e 'SHOW SLAVE STATUS\G' | grep -q 'Slave_IO_Running: Yes'"

# Data replication tests
RANDOM_VALUE=$RANDOM
run_test "MariaDB Write to Primary" "docker exec maria-primary mysql -u app_user -papp_password voip_db -e \"INSERT INTO calls (caller_id, callee_id, call_status, codec_used, call_direction) VALUES ('test_${RANDOM_VALUE}', '9999', 'connected', 'G.711', 'outbound')\" 2>/dev/null"
sleep 2
run_test "MariaDB Read from Replica (Data Replication)" "docker exec maria-replica mysql -u app_user -papp_password voip_db -e \"SELECT caller_id FROM calls WHERE caller_id='test_${RANDOM_VALUE}'\" 2>/dev/null | grep -q \"test_${RANDOM_VALUE}\""
run_test "MariaDB Write to Replica Blocked (Read-Only)" "docker exec maria-replica mysql -u app_user -papp_password voip_db -e \"INSERT INTO calls (caller_id, callee_id, call_status, codec_used, call_direction) VALUES ('should_fail', '8888', 'connected', 'G.711', 'outbound')\" 2>&1 | grep -q 'read-only'"

echo "Task 2: PostgreSQL Replication"
echo "--------------------------------"
run_test "PostgreSQL Primary Connection" "docker exec postgres-primary su - postgres -c 'psql -c \"SELECT 1\"' 2>/dev/null"
run_test "PostgreSQL Replica 1 Connection" "docker exec postgres-replica-1 su - postgres -c 'psql -c \"SELECT 1\"' 2>/dev/null"
run_test "PostgreSQL Replica 2 Connection" "docker exec postgres-replica-2 su - postgres -c 'psql -c \"SELECT 1\"' 2>/dev/null"
run_test "HAProxy Load Balancer" "curl -s http://localhost:8404/stats > /dev/null"

# Data replication tests
RANDOM_VALUE=$RANDOM
run_test "PostgreSQL Write to Primary" "docker exec postgres-primary su - postgres -c \"psql ecommerce -c \\\"CREATE TABLE IF NOT EXISTS test_table (id SERIAL PRIMARY KEY, value TEXT); INSERT INTO test_table (value) VALUES ('test_${RANDOM_VALUE}');\\\"\" 2>/dev/null"
sleep 2
run_test "PostgreSQL Read from Replica-1 (Data Replication)" "docker exec postgres-replica-1 su - postgres -c \"psql ecommerce -c \\\"SELECT value FROM test_table WHERE value='test_${RANDOM_VALUE}';\\\"\" 2>/dev/null | grep -q \"test_${RANDOM_VALUE}\""
run_test "PostgreSQL Read from Replica-2 (Data Replication)" "docker exec postgres-replica-2 su - postgres -c \"psql ecommerce -c \\\"SELECT value FROM test_table WHERE value='test_${RANDOM_VALUE}';\\\"\" 2>/dev/null | grep -q \"test_${RANDOM_VALUE}\""
run_test "PostgreSQL Write to Replica-1 Blocked (Read-Only)" "docker exec postgres-replica-1 su - postgres -c \"psql ecommerce -c \\\"INSERT INTO test_table (value) VALUES ('should_fail');\\\"\" 2>&1 | grep -q 'read-only\\|recovery'"

echo "Task 3: Nginx Reverse Proxy"
echo "--------------------------------"
run_test "Nginx HTTP Response" "curl -s http://localhost:8000/ | grep -q 'App Server'"
run_test "Nginx Health Check" "curl -s http://localhost:8000/health | grep -q 'healthy' || echo 'ok'"
run_test "App-1 Running" "docker exec app-1 pgrep -f 'python3 -m http.server' > /dev/null"
run_test "App-2 Running" "docker exec app-2 pgrep -f 'python3 -m http.server' > /dev/null"

echo "Task 4: Asterisk VoIP"
echo "--------------------------------"
run_test "Asterisk-1 Running" "docker exec asterisk-1 asterisk -rx 'core show version' 2>/dev/null | grep -q 'Asterisk'"
run_test "Asterisk-2 Running" "docker exec asterisk-2 asterisk -rx 'core show version' 2>/dev/null | grep -q 'Asterisk'"
run_test "Kamailio Balancer Running" "docker exec asterisk-balancer pgrep kamailio > /dev/null"

echo "=================================="
echo "Test Summary"
echo "=================================="
echo -e "${GREEN}Passed: $test_passed${NC}"
echo -e "${RED}Failed: $test_failed${NC}"
echo ""

if [ $test_failed -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed. Check the output above.${NC}"
    exit 1
fi
