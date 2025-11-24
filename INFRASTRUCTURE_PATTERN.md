# Infrastructure Development Pattern

This document describes the preferred pattern for developing and testing infrastructure components in this project.

## Pattern Overview

**Test locally first, then deploy to production**

1. **Unified Ansible roles and playbooks** - Same code works for both Docker and production
2. **Docker-based local testing** - Fast iteration without touching production
3. **Automated test scripts** - Verify functionality in both environments
4. **Gradual deployment** - Test thoroughly locally before production deployment

## Directory Structure

```
project/
├── ansible/
│   ├── playbooks/
│   │   ├── component.yml              # Master playbook (imports primary + replica)
│   │   ├── component-primary.yml      # Unified primary playbook
│   │   └── component-replica.yml      # Unified replica playbook (if applicable)
│   ├── roles/
│   │   ├── component-primary/
│   │   │   ├── tasks/main.yml
│   │   │   ├── templates/
│   │   │   ├── handlers/main.yml
│   │   │   └── defaults/main.yml
│   │   └── component-replica/         # If applicable
│   ├── inventory/
│   │   ├── hosts.yml                  # Production inventory
│   │   └── hosts-docker-test.yml      # Docker testing inventory
│   ├── test-component.sh              # Automated test script
│   └── start-services.sh              # Helper for Docker (if needed)
└── docker/
    └── docker-compose.yml              # Docker test environment
```

## Step-by-Step Workflow

### Step 1: Create Ansible Roles

Create roles with clear separation of concerns:

```yaml
# roles/component-primary/tasks/main.yml
---
- name: Install component
  apt:
    name: component-package
    state: present

- name: Configure component
  template:
    src: config.j2
    dest: /etc/component/config.conf
  notify: restart component

- name: Ensure component is running
  service:
    name: component
    state: started
    enabled: yes
```

**Key principles:**
- Use variables from `defaults/main.yml` for all configurable values
- Use templates for configuration files
- Keep tasks idempotent (safe to run multiple times)
- Use handlers for service restarts

### Step 2: Create Unified Playbooks

Use host patterns to create playbooks that work for both environments:

```yaml
# playbooks/component-primary.yml
---
# Unified playbook for Component Primary
# Works for both Docker testing and production VMs
#
# Usage:
#   Docker:      ansible-playbook -i inventory/hosts-docker-test.yml playbooks/component-primary.yml
#   Production:  ansible-playbook playbooks/component-primary.yml

- name: Configure Component Primary
  hosts: component:&*primary*   # Targets hosts in 'component' group with 'primary' in name
  become: yes

  roles:
    - common
    - component-primary

  tasks:
    - name: Verify component is running
      service:
        name: component
        state: started
      tags: verify
      ignore_errors: yes  # May not work in Docker without systemd
```

**Host pattern explained:**
- `component:&*primary*` - Intersection of 'component' group AND hosts matching '*primary*'
- Works with both `component-primary` and `component-primary-test` hostnames

### Step 3: Configure Inventories

#### Production Inventory (`inventory/hosts.yml`)

```yaml
all:
  children:
    component:
      hosts:
        component-primary:
          ansible_host: 1.2.3.4
        component-replica:
          ansible_host: 5.6.7.8
          # Environment-specific overrides
          component_primary_host: "1.2.3.4"

  vars:
    ansible_user: root
    ansible_ssh_private_key_file: ~/.ssh/key
    ansible_python_interpreter: /usr/bin/python3
```

#### Docker Testing Inventory (`inventory/hosts-docker-test.yml`)

```yaml
all:
  vars:
    ansible_user: root
    ansible_ssh_private_key_file: ~/.ssh/redi_test_key
    ansible_ssh_common_args: '-o StrictHostKeyChecking=no'
    ansible_python_interpreter: /usr/bin/python3

  children:
    component:
      hosts:
        component-primary-test:
          ansible_host: localhost
          ansible_port: 2201
        component-replica-test:
          ansible_host: localhost
          ansible_port: 2202
          # Docker-specific overrides (use Docker network IPs)
          component_primary_host: "172.20.0.10"
```

### Step 4: Create Docker Test Environment

Update `docker-compose.yml` to include your new component:

```yaml
services:
  component-primary-test:
    build: ./docker
    hostname: component-primary-test
    container_name: component-primary-test
    networks:
      test_network:
        ipv4_address: 172.20.0.20
    ports:
      - "2201:22"
    volumes:
      - ./ansible:/ansible:ro

networks:
  test_network:
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/16
```

### Step 5: Create Automated Test Script

Create `test-component.sh` following this template:

```bash
#!/bin/bash
# Unified test script for Component
# Usage: ./test-component.sh [docker|prod|all]

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test tracking
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

test_component_environment() {
    local ENV_NAME="$1"
    local INVENTORY="$2"
    local PRIMARY_HOST="$3"

    print_header "Testing Component - $(echo ${ENV_NAME} | tr '[:lower:]' '[:upper:]') Environment"

    # Test 1: Connectivity
    print_test "Server connectivity"
    if ansible "$PRIMARY_HOST" -i "$INVENTORY" -m ping &>/dev/null; then
        print_success "Server is accessible"
    else
        print_failure "Cannot connect to server"
        return
    fi

    # Add more tests here...

}

# Main execution
ENV="${1:-docker}"

if [ "$ENV" == "docker" ] || [ "$ENV" == "all" ]; then
    test_component_environment "docker" "inventory/hosts-docker-test.yml" "component-primary-test"
fi

if [ "$ENV" == "prod" ] || [ "$ENV" == "all" ]; then
    test_component_environment "production" "inventory/hosts.yml" "component-primary"
fi

# Summary
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
```

### Step 6: Development Workflow

Follow this workflow for each new infrastructure component:

#### 6.1 Initial Development

```bash
# 1. Start Docker test environment
cd docker
docker-compose up -d component-primary-test

# 2. Develop Ansible role
cd ../ansible
ansible-playbook -i inventory/hosts-docker-test.yml playbooks/component-primary.yml

# 3. Iterate until it works
# Make changes to roles/tasks
# Re-run playbook
# Check logs in container if needed
```

#### 6.2 Testing Phase

```bash
# 1. Test on Docker
./test-component.sh docker

# 2. If tests fail, fix and re-run
# 3. Once all tests pass, proceed to production
```

#### 6.3 Production Deployment

```bash
# 1. Run playbook on production
ansible-playbook playbooks/component-primary.yml

# 2. Verify with tests
./test-component.sh prod

# 3. Run both to ensure parity
./test-component.sh all
```

## Common Patterns and Best Practices

### Handler Pattern for Docker Compatibility

Docker containers without systemd need special handling:

```yaml
# roles/component/handlers/main.yml
---
- name: restart component
  shell: /usr/sbin/service component restart
  async: 1
  poll: 0
  ignore_errors: yes
```

**Why:**
- Docker containers may not have systemd
- Async mode prevents connection drops
- `ignore_errors` allows deployment to continue
- Services can be started manually in Docker with helper script

### Variable Override Pattern

Use inventory variables for environment-specific overrides:

```yaml
# defaults/main.yml (role defaults)
component_primary_host: "component-primary"  # Default hostname

# inventory/hosts-docker-test.yml (Docker override)
component-replica-test:
  component_primary_host: "172.20.0.10"  # Use Docker network IP

# inventory/hosts.yml (Production override)
component-replica:
  component_primary_host: "1.2.3.4"  # Use real IP address
```

### Verification Task Pattern

Include verification tasks in playbooks:

```yaml
tasks:
  - name: Verify component is accessible
    command: component-cli status
    register: status_output
    changed_when: false
    failed_when: false
    tags: verify

  - name: Display status
    debug:
      var: status_output.stdout_lines
    when: status_output.rc == 0
    tags: verify
```

### Test Script Pattern

Structure tests from simple to complex:

1. **Connectivity tests** - Can we reach the server?
2. **Installation tests** - Is the software installed?
3. **Service tests** - Is the service running?
4. **Functionality tests** - Does it actually work?
5. **Integration tests** - Do components work together?

## Example: MariaDB Pattern (Reference Implementation)

See the MariaDB implementation as a reference:

- **Playbooks**: `ansible/playbooks/mariadb*.yml`
- **Roles**: `ansible/roles/mariadb-primary/`, `ansible/roles/mariadb-replica/`
- **Test Script**: `ansible/test-mariadb.sh`
- **Docker Config**: `docker/docker-compose.yml` (maria-primary-test, maria-replica-test)

The MariaDB setup demonstrates:
- ✅ Unified playbooks using host patterns
- ✅ Environment-specific variable overrides
- ✅ Comprehensive test coverage (13 tests)
- ✅ Docker and production parity
- ✅ Async handlers for Docker compatibility

## Benefits of This Pattern

1. **Faster Development** - Test locally without risking production
2. **Confidence** - Know it works before deploying to production
3. **Consistency** - Same code runs everywhere
4. **Automated Testing** - Catch issues early
5. **Documentation** - Tests serve as living documentation
6. **Reproducibility** - Easy to recreate environments
7. **Parallel Development** - Multiple developers can work on different components

## Checklist for New Components

Use this checklist when implementing new infrastructure:

- [ ] Created Ansible role(s) in `ansible/roles/`
- [ ] Created unified playbook(s) in `ansible/playbooks/`
- [ ] Added component to both inventory files
- [ ] Updated `docker-compose.yml` with test containers
- [ ] Created automated test script `test-component.sh`
- [ ] Tested on Docker environment (all tests pass)
- [ ] Deployed to production
- [ ] Tested on production (all tests pass)
- [ ] Verified both environments work identically (`test-component.sh all`)
- [ ] Documented any component-specific notes

## Next Infrastructure Components

Apply this pattern to upcoming tasks:

1. **PostgreSQL Replication** - Similar to MariaDB, with primary + 2 replicas
2. **HAProxy Load Balancer** - For PostgreSQL read distribution
3. **Nginx Reverse Proxy** - For web application load balancing
4. **Asterisk VoIP** - Two servers with load balancer
5. **Application Servers** - Multiple instances behind Nginx

Each should follow the same pattern: develop locally, test automatically, deploy confidently.
