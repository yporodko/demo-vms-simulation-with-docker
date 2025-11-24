# Quick Pattern Reference Card

**One-page reference for the infrastructure development pattern**

## 🎯 Core Principle

> **Test locally with Docker first, then deploy to production**

## 📁 File Structure for New Component

```
ansible/
├── roles/
│   └── component-primary/
│       ├── tasks/main.yml       # What to install/configure
│       ├── templates/           # Config file templates
│       ├── handlers/main.yml    # Service restart handlers
│       └── defaults/main.yml    # Default variables
├── playbooks/
│   ├── component.yml            # Master playbook
│   └── component-primary.yml    # Unified playbook (docker + prod)
├── inventory/
│   ├── hosts.yml                # Production hosts
│   └── hosts-docker-test.yml    # Docker test hosts
└── test-component.sh            # Automated tests
```

## 🚀 Workflow (3 Steps)

### 1️⃣ Develop & Test Locally

```bash
# Start Docker test container
cd docker && docker-compose up -d component-primary-test

# Deploy with Ansible
cd ../ansible
ansible-playbook -i inventory/hosts-docker-test.yml playbooks/component-primary.yml

# Run automated tests
./test-component.sh docker
```

### 2️⃣ Verify Tests Pass

```bash
# All tests must pass before production deployment
./test-component.sh docker

# Fix any issues and re-run until all tests pass
```

### 3️⃣ Deploy to Production

```bash
# Deploy to production
ansible-playbook playbooks/component-primary.yml

# Verify with tests
./test-component.sh prod

# Confirm both environments work identically
./test-component.sh all
```

## 📝 Unified Playbook Pattern

**Key:** Use host patterns to target both Docker and production

```yaml
# playbooks/component-primary.yml
---
- name: Configure Component Primary
  hosts: component:&*primary*  # ← Matches both component-primary and component-primary-test
  become: yes

  roles:
    - common
    - component-primary
```

## 🔧 Inventory Pattern

### Production (`inventory/hosts.yml`)

```yaml
component:
  hosts:
    component-primary:
      ansible_host: 1.2.3.4
```

### Docker Test (`inventory/hosts-docker-test.yml`)

```yaml
component:
  hosts:
    component-primary-test:       # ← Note: -test suffix
      ansible_host: localhost
      ansible_port: 2201
```

## ✅ Test Script Pattern

**Structure:** Simple → Complex

1. Connectivity (can we reach it?)
2. Installation (is it installed?)
3. Service Status (is it running?)
4. Functionality (does it work?)
5. Integration (do components work together?)

```bash
# Usage
./test-component.sh docker  # Test Docker only
./test-component.sh prod    # Test production only
./test-component.sh all     # Test both environments
```

## 🎨 Color Output

- 🟢 **Green** = Test passed
- 🔴 **Red** = Test failed
- 🟡 **Yellow** = Test name
- 🔵 **Blue** = Info/header

## 📋 Checklist for New Component

- [ ] Copy template: `cp -r ansible/templates/component-template ansible/templates/my-component`
- [ ] Create Ansible role in `ansible/roles/`
- [ ] Create unified playbook in `ansible/playbooks/`
- [ ] Add to both inventory files
- [ ] Add to `docker-compose.yml`
- [ ] Create test script `test-component.sh`
- [ ] **Test on Docker** (all tests pass)
- [ ] Deploy to production
- [ ] **Test on production** (all tests pass)
- [ ] Verify both: `./test-component.sh all`

## 🔑 Key Patterns

### Handler Pattern (Docker Compatible)

```yaml
# handlers/main.yml
- name: restart component
  shell: /usr/sbin/service component restart
  async: 1           # Don't wait
  poll: 0            # Don't check result
  ignore_errors: yes # Docker may not have systemd
```

### Variable Override Pattern

```yaml
# defaults/main.yml
component_primary_host: "component-primary"  # Default

# inventory/hosts-docker-test.yml (override)
component_primary_host: "172.20.0.10"  # Docker network IP

# inventory/hosts.yml (override)
component_primary_host: "1.2.3.4"  # Real IP
```

## 📚 Full Documentation

See [INFRASTRUCTURE_PATTERN.md](INFRASTRUCTURE_PATTERN.md) for complete details.

## 💡 Example: MariaDB

Perfect reference implementation in this repo:
- Playbooks: `ansible/playbooks/mariadb*.yml`
- Roles: `ansible/roles/mariadb-{primary,replica}/`
- Tests: `ansible/test-mariadb.sh`
- Results: 26/26 tests pass (Docker + Production)
