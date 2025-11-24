#!/bin/bash
# Unified test script for COMPONENT
# Works for both Docker testing and production VMs
#
# Usage:
#   Docker:      ./test-component.sh docker
#   Production:  ./test-component.sh prod
#   Both:        ./test-component.sh all

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

test_component_environment() {
    local ENV_NAME="$1"
    local INVENTORY="$2"
    local PRIMARY_HOST="$3"

    print_header "Testing COMPONENT - $(echo ${ENV_NAME} | tr '[:lower:]' '[:upper:]') Environment"

    # Test 1: Check if primary is accessible
    print_test "Primary server connectivity"
    if ansible "$PRIMARY_HOST" -i "$INVENTORY" -m ping &>/dev/null; then
        print_success "Primary server is accessible"
    else
        print_failure "Cannot connect to primary server"
        return
    fi

    # Test 2: Check COMPONENT is installed
    print_test "COMPONENT installation check"
    if ansible "$PRIMARY_HOST" -i "$INVENTORY" -m shell -a "which component-cli" &>/dev/null; then
        VERSION=$(ansible "$PRIMARY_HOST" -i "$INVENTORY" -m shell -a "component-cli --version" 2>/dev/null | tail -1)
        print_success "COMPONENT is installed (version: $VERSION)"
    else
        print_failure "COMPONENT is not installed"
    fi

    # Test 3: Check COMPONENT service status
    print_test "COMPONENT service status"
    if ansible "$PRIMARY_HOST" -i "$INVENTORY" -m shell -a "component-cli status" &>/dev/null; then
        print_success "COMPONENT service is running"
    else
        print_failure "COMPONENT service is not running"
    fi

    # Add more component-specific tests here
    # Examples:
    # - Test 4: Check configuration
    # - Test 5: Test connectivity to component port
    # - Test 6: Create test data
    # - Test 7: Verify test data
    # - Test 8: Test component-specific functionality
}

# Main execution
if [ "$ENV" == "docker" ] || [ "$ENV" == "all" ]; then
    test_component_environment "docker" "inventory/hosts-docker-test.yml" "component-primary-test"
fi

if [ "$ENV" == "prod" ] || [ "$ENV" == "all" ]; then
    test_component_environment "production" "inventory/hosts.yml" "component-primary"
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
