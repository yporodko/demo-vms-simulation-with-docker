#!/bin/bash
# Nginx Load Balancer Test Script
# Tests load balancing and DDoS protection configuration

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
INVENTORY="inventory/hosts.yml"
NGINX_HOST="nginx"
NGINX_IP="157.180.118.98"

TESTS_PASSED=0
TESTS_FAILED=0

print_test() {
    echo -e "${YELLOW}[TEST]${NC} $1"
}

print_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((TESTS_PASSED++))
}

print_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((TESTS_FAILED++))
}

echo "========================================"
echo "Nginx Load Balancer Test Suite"
echo "========================================"
echo ""

# Test 1: Check Nginx is running
print_test "Nginx service status"
NGINX_STATUS=$(ansible "$NGINX_HOST" -i "$INVENTORY" -m shell -a "systemctl is-active nginx" 2>/dev/null | grep -oE "^active$" || echo "inactive")
if [ "$NGINX_STATUS" == "active" ]; then
    print_pass "Nginx is running"
else
    print_fail "Nginx is not running"
fi

# Test 2: Check Nginx configuration is valid
print_test "Nginx configuration syntax"
CONFIG_CHECK=$(ansible "$NGINX_HOST" -i "$INVENTORY" -m shell -a "nginx -t 2>&1" 2>/dev/null | grep -c "syntax is ok" || echo "0")
if [ "$CONFIG_CHECK" -ge 1 ]; then
    print_pass "Nginx configuration is valid"
else
    print_fail "Nginx configuration has errors"
fi

# Test 3: Check Nginx is listening on port 80
print_test "Nginx listening on port 80"
PORT_80=$(ansible "$NGINX_HOST" -i "$INVENTORY" -m shell -a "ss -tlnp | grep ':80 '" 2>/dev/null | grep -c "nginx" || echo "0")
if [ "$PORT_80" -ge 1 ]; then
    print_pass "Nginx is listening on port 80"
else
    print_fail "Nginx is not listening on port 80"
fi

# Test 4: Check app-1 is running
print_test "App-1 service status"
APP1_STATUS=$(ansible "app-1" -i "$INVENTORY" -m shell -a "systemctl is-active simple-app" 2>/dev/null | grep -oE "^active$" || echo "inactive")
if [ "$APP1_STATUS" == "active" ]; then
    print_pass "App-1 is running"
else
    print_fail "App-1 is not running"
fi

# Test 5: Check app-2 is running
print_test "App-2 service status"
APP2_STATUS=$(ansible "app-2" -i "$INVENTORY" -m shell -a "systemctl is-active simple-app" 2>/dev/null | grep -oE "^active$" || echo "inactive")
if [ "$APP2_STATUS" == "active" ]; then
    print_pass "App-2 is running"
else
    print_fail "App-2 is not running"
fi

# Test 6: Check app-1 is listening on port 8080
print_test "App-1 listening on port 8080"
APP1_PORT=$(ansible "app-1" -i "$INVENTORY" -m shell -a "ss -tlnp | grep ':8080 '" 2>/dev/null | grep -c "python" || echo "0")
if [ "$APP1_PORT" -ge 1 ]; then
    print_pass "App-1 is listening on port 8080"
else
    print_fail "App-1 is not listening on port 8080"
fi

# Test 7: Check app-2 is listening on port 8080
print_test "App-2 listening on port 8080"
APP2_PORT=$(ansible "app-2" -i "$INVENTORY" -m shell -a "ss -tlnp | grep ':8080 '" 2>/dev/null | grep -c "python" || echo "0")
if [ "$APP2_PORT" -ge 1 ]; then
    print_pass "App-2 is listening on port 8080"
else
    print_fail "App-2 is not listening on port 8080"
fi

# Test 8: Check DDoS protection - rate limiting zone configured
print_test "Rate limiting zone configured"
RATE_LIMIT=$(ansible "$NGINX_HOST" -i "$INVENTORY" -m shell -a "grep 'limit_req_zone' /etc/nginx/nginx.conf" 2>/dev/null | grep -c "req_limit_per_ip" || echo "0")
if [ "$RATE_LIMIT" -ge 1 ]; then
    print_pass "Rate limiting zone is configured"
else
    print_fail "Rate limiting zone is not configured"
fi

# Test 9: Check DDoS protection - connection limiting zone configured
print_test "Connection limiting zone configured"
CONN_LIMIT=$(ansible "$NGINX_HOST" -i "$INVENTORY" -m shell -a "grep 'limit_conn_zone' /etc/nginx/nginx.conf" 2>/dev/null | grep -c "conn_limit_per_ip" || echo "0")
if [ "$CONN_LIMIT" -ge 1 ]; then
    print_pass "Connection limiting zone is configured"
else
    print_fail "Connection limiting zone is not configured"
fi

# Test 10: Check upstream configuration
print_test "Upstream backend_servers configured"
UPSTREAM=$(ansible "$NGINX_HOST" -i "$INVENTORY" -m shell -a "grep -A 10 'upstream backend_servers' /etc/nginx/nginx.conf" 2>/dev/null | grep -c "server" || echo "0")
if [ "$UPSTREAM" -ge 2 ]; then
    print_pass "Upstream has 2+ backend servers configured"
else
    print_fail "Upstream backend servers not properly configured"
fi

# Test 11: Check load balancing method
print_test "Load balancing method configured"
LB_METHOD=$(ansible "$NGINX_HOST" -i "$INVENTORY" -m shell -a "grep 'least_conn' /etc/nginx/nginx.conf" 2>/dev/null | grep -c "least_conn" || echo "0")
if [ "$LB_METHOD" -ge 1 ]; then
    print_pass "Least connections load balancing is configured"
else
    print_fail "Load balancing method not configured (or using round-robin)"
fi

# Test 12: Check proxy headers configured
print_test "Proxy headers configured"
PROXY_HEADERS=$(ansible "$NGINX_HOST" -i "$INVENTORY" -m shell -a "grep 'proxy_set_header' /etc/nginx/sites-available/proxy.conf" 2>/dev/null | grep -c "X-Real-IP" || echo "0")
if [ "$PROXY_HEADERS" -ge 1 ]; then
    print_pass "Proxy headers (X-Real-IP) are configured"
else
    print_fail "Proxy headers not configured"
fi

# Test 13: Check Nginx health endpoint responds
print_test "Nginx health endpoint"
HEALTH=$(curl -s --connect-timeout 5 "http://$NGINX_IP/nginx-health" 2>/dev/null || echo "")
if [ "$HEALTH" == "healthy" ]; then
    print_pass "Nginx health endpoint responds correctly"
else
    print_fail "Nginx health endpoint not responding"
fi

# Test 14: Check Nginx status page
print_test "Nginx status page"
STATUS_PAGE=$(curl -s --connect-timeout 5 "http://$NGINX_IP/nginx-status" 2>/dev/null | grep -c "Active connections" || echo "0")
if [ "$STATUS_PAGE" -ge 1 ]; then
    print_pass "Nginx status page is accessible"
else
    print_fail "Nginx status page not accessible"
fi

# Test 15: Check load balancing works (if backends are accessible)
print_test "Load balancing (multiple requests)"
HOSTS=""
for i in {1..4}; do
    RESPONSE=$(curl -s --connect-timeout 5 "http://$NGINX_IP/" 2>/dev/null | grep -o '"hostname": "[^"]*"' | cut -d'"' -f4 || echo "")
    if [ -n "$RESPONSE" ]; then
        HOSTS="$HOSTS $RESPONSE"
    fi
done

if echo "$HOSTS" | grep -q "app-1" && echo "$HOSTS" | grep -q "app-2"; then
    print_pass "Load balancing distributes to both app-1 and app-2"
elif [ -z "$HOSTS" ]; then
    print_fail "Could not connect to backends (may be network/firewall issue)"
else
    print_fail "Load balancing not distributing to both backends"
fi

echo ""
echo "========================================"
echo "Test Summary"
echo "========================================"
echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
echo -e "${RED}Failed: $TESTS_FAILED${NC}"
TOTAL=$((TESTS_PASSED + TESTS_FAILED))
echo "Total:  $TOTAL"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed.${NC}"
    exit 1
fi
