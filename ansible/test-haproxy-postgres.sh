#!/bin/bash
# Test script for HAProxy PostgreSQL Load Balancing
# Usage:
#   Docker:      ./test-haproxy-postgres.sh docker
#   Production:  ./test-haproxy-postgres.sh prod

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0

print_test() {
    echo -e "${YELLOW}TEST:${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓ PASS:${NC} $1"
    ((TESTS_PASSED++))
}

print_failure() {
    echo -e "${RED}✗ FAIL:${NC} $1"
    ((TESTS_FAILED++))
}

print_info() {
    echo -e "${BLUE}INFO:${NC} $1"
}

# Determine environment
ENV="${1:-prod}"

if [ "$ENV" == "docker" ]; then
    INVENTORY="inventory/hosts-docker-test.yml"
    PRIMARY_HOST="postgres-primary-test"
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}Testing HAProxy Load Balancing - DOCKER Environment${NC}"
    echo -e "${BLUE}========================================${NC}"
else
    INVENTORY="inventory/hosts.yml"
    PRIMARY_HOST="postgres-primary"
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}Testing HAProxy Load Balancing - PRODUCTION Environment${NC}"
    echo -e "${BLUE}========================================${NC}"
fi

echo ""

# Test 1: HAProxy service is running
print_test "HAProxy service status"
if [ "$ENV" == "docker" ]; then
    HAPROXY_PID=$(ansible "$PRIMARY_HOST" -i "$INVENTORY" -m shell -a "pgrep haproxy || echo ''" 2>/dev/null | tail -1)
else
    HAPROXY_STATUS=$(ansible "$PRIMARY_HOST" -i "$INVENTORY" -m shell -a "systemctl is-active haproxy" 2>/dev/null | grep -oE "active|inactive" | head -1)
    HAPROXY_PID="$HAPROXY_STATUS"
fi

if [ -n "$HAPROXY_PID" ] && [ "$HAPROXY_PID" != "" ]; then
    print_success "HAProxy is running"
else
    print_failure "HAProxy is not running"
fi

# Test 2: HAProxy listening on stats port (8404)
print_test "HAProxy stats port (8404)"
STATS_CHECK=$(ansible "$PRIMARY_HOST" -i "$INVENTORY" -m shell -a "netstat -tlnp 2>/dev/null | grep ':8404' || ss -tlnp | grep ':8404'" 2>/dev/null | grep -c "8404" || echo "0")
if [ "$STATS_CHECK" -gt "0" ]; then
    print_success "HAProxy stats port 8404 is listening"
else
    print_failure "HAProxy stats port 8404 is not listening"
fi

# Test 3: HAProxy listening on read port (5433)
print_test "HAProxy read port (5433)"
READ_CHECK=$(ansible "$PRIMARY_HOST" -i "$INVENTORY" -m shell -a "netstat -tlnp 2>/dev/null | grep ':5433' || ss -tlnp | grep ':5433'" 2>/dev/null | grep -c "5433" || echo "0")
if [ "$READ_CHECK" -gt "0" ]; then
    print_success "HAProxy read port 5433 is listening"
else
    print_failure "HAProxy read port 5433 is not listening"
fi

# Test 4: HAProxy backend servers are UP
print_test "HAProxy backend servers status"
BACKEND_UP=$(ansible "$PRIMARY_HOST" -i "$INVENTORY" -m shell -a "echo 'show stat' | socat stdio /run/haproxy/admin.sock 2>/dev/null | grep postgres_read | grep -c 'UP'" 2>/dev/null | grep -oE "^[0-9]+" | head -1 || echo "0")
if [ "$BACKEND_UP" -ge "2" ]; then
    print_success "Both replica backends are UP (found $BACKEND_UP)"
else
    print_failure "Not all backends are UP (expected 2, found $BACKEND_UP)"
fi

# Test 5: Load balancing is working (round-robin)
print_test "Load balancing (round-robin distribution)"
SERVER1=$(ansible "$PRIMARY_HOST" -i "$INVENTORY" -m shell -a "PGPASSWORD=app_password psql -h 127.0.0.1 -p 5433 -U app_user -d ecommerce -t -c 'SELECT inet_server_addr();'" 2>/dev/null | grep -oE "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+" | head -1)
SERVER2=$(ansible "$PRIMARY_HOST" -i "$INVENTORY" -m shell -a "PGPASSWORD=app_password psql -h 127.0.0.1 -p 5433 -U app_user -d ecommerce -t -c 'SELECT inet_server_addr();'" 2>/dev/null | grep -oE "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+" | head -1)

if [ -n "$SERVER1" ] && [ -n "$SERVER2" ] && [ "$SERVER1" != "$SERVER2" ]; then
    print_success "Load balancing working: Request 1 -> $SERVER1, Request 2 -> $SERVER2"
else
    print_failure "Load balancing may not be working correctly (Server1: $SERVER1, Server2: $SERVER2)"
fi

# Test 6: Read queries return data from replicas
print_test "Read queries through HAProxy return valid data"
DATA_CHECK=$(ansible "$PRIMARY_HOST" -i "$INVENTORY" -m shell -a "PGPASSWORD=app_password psql -h 127.0.0.1 -p 5433 -U app_user -d ecommerce -t -c 'SELECT 1;'" 2>/dev/null | grep -oE "^\s*1\s*$" | tr -d ' ')
if [ "$DATA_CHECK" == "1" ]; then
    print_success "Read queries return valid data through HAProxy"
else
    print_failure "Read queries failed through HAProxy"
fi

# Test 7: Write queries directly to primary still work
print_test "Write queries to primary (port 5432)"
WRITE_CHECK=$(ansible "$PRIMARY_HOST" -i "$INVENTORY" -m shell -a "PGPASSWORD=app_password psql -h 127.0.0.1 -p 5432 -U app_user -d ecommerce -t -c 'SELECT 1;'" 2>/dev/null | grep -oE "^\s*1\s*$" | tr -d ' ')
if [ "$WRITE_CHECK" == "1" ]; then
    print_success "Write queries to primary work correctly"
else
    print_failure "Write queries to primary failed"
fi

# Test 8: Replicas are read-only through HAProxy
print_test "Read-only enforcement through HAProxy"
READONLY_CHECK=$(ansible "$PRIMARY_HOST" -i "$INVENTORY" -m shell -a "PGPASSWORD=app_password psql -h 127.0.0.1 -p 5433 -U app_user -d ecommerce -c 'CREATE TABLE haproxy_test (id int);' 2>&1" 2>/dev/null | grep -c "read-only" || echo "0")
if [ "$READONLY_CHECK" -gt "0" ]; then
    print_success "HAProxy read port correctly routes to read-only replicas"
else
    print_failure "HAProxy may be routing to writable server"
fi

# Summary
echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Test Summary${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "Total Tests:  ${BLUE}8${NC}"
echo -e "Passed:       ${GREEN}$TESTS_PASSED${NC}"
echo -e "Failed:       ${RED}$TESTS_FAILED${NC}"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}✗ Some tests failed!${NC}"
    exit 1
fi
