# Infrastructure Configuration with Ansible

Automated configuration management for VoIP and database infrastructure using Ansible.

## Overview

This project uses **Ansible** to configure and manage:
- MariaDB Primary/Replica (replication setup)
- PostgreSQL Primary + 2 Replicas + HAProxy load balancer
- Nginx reverse proxy with DDoS protection
- Application servers
- Asterisk VoIP servers + Kamailio load balancer
- SIPp testing tools

## Quick Start

### Prerequisites

- Ansible installed: `pip3 install ansible` or `brew install ansible`
- Docker installed (for local testing)
- SSH access to VMs configured in `~/.ssh/config`
- SSH key: `~/.ssh/redi_test_key`

### Option 1: Test Locally with Docker (Recommended)

```bash
# Start Docker containers and configure SSH
./test-docker.sh start

# Deploy maria-primary to Docker
./test-docker.sh deploy

# Verify
./test-docker.sh ssh maria-primary-test
mysql -u app_user -papp_password voip_db -e "SHOW TABLES;"
```

### Option 2: Deploy to Production VMs

```bash
cd ansible

# Test connection
ansible maria-primary -m ping

# Deploy (dry run first)
ansible-playbook playbooks/maria-primary.yml --check

# Deploy for real
ansible-playbook playbooks/maria-primary.yml

# Verify
ssh maria-primary
mysql -u app_user -papp_password voip_db -e "SHOW TABLES;"
```

## Documentation

### Development Pattern ⭐ NEW
- **[INFRASTRUCTURE_PATTERN.md](INFRASTRUCTURE_PATTERN.md)** - **Standard pattern for all infrastructure components**
  - Unified Ansible roles and playbooks
  - Docker-based local testing
  - Automated test scripts
  - Test locally first, then deploy to production
  - **Use this for all new infrastructure work!**

### Getting Started
- **[ansible/DOCKER-TESTING.md](ansible/DOCKER-TESTING.md)** - Test playbooks locally with Docker (recommended first step)
- **[ansible/QUICK-START.md](ansible/QUICK-START.md)** - 5-minute getting started guide
- **[ansible/ANSIBLE-BEGINNERS-GUIDE.md](ansible/ANSIBLE-BEGINNERS-GUIDE.md)** - Complete Ansible tutorial
- **[ansible/README.md](ansible/README.md)** - Ansible setup reference

### Infrastructure Details
- **[docs/NGINX-DDOS-PROTECTION.md](docs/NGINX-DDOS-PROTECTION.md)** - Nginx DDoS protection configuration
- **[docs/ASTERISK-GUIDE.md](docs/ASTERISK-GUIDE.md)** - VoIP and SIP configuration
- **[docs/KAMAILIO-CHANGE.md](docs/KAMAILIO-CHANGE.md)** - Kamailio load balancer notes

### Archived Documentation
- **[docs/archived/](docs/archived/)** - Previous approaches (for reference)

## Directory Structure

```
.
├── ansible/                    # Ansible configuration (MAIN TOOL)
│   ├── inventory/             # VM definitions
│   ├── roles/                 # Reusable configurations
│   │   ├── common/           # Base setup for all servers
│   │   └── mariadb-primary/  # MariaDB primary server
│   └── playbooks/            # Deployment orchestration
│
├── docker-compose.yml         # Docker simulation (for local testing)
├── docker-base/              # Base VM simulation image
│
├── maria-primary/            # MariaDB primary config files
├── postgres-primary/         # PostgreSQL primary config
├── nginx/                    # Nginx reverse proxy
├── asterisk-1/              # Asterisk VoIP servers
│
├── VM hosts.txt             # VM inventory (hostname IP pairs)
└── docs/                    # Documentation
```

## Project Tasks

This infrastructure supports 4 main tasks:

### Task 1: MariaDB Replication
- **Primary:** maria-primary (157.180.114.52)
- **Replica:** maria-replica (37.27.248.240)
- Binary log replication, read-only replica
- Database: voip_db

### Task 2: PostgreSQL Load Balancing
- **Primary:** postgres-primary (46.62.207.138)
- **Replicas:** postgres-replica-1, postgres-replica-2
- **Load Balancer:** HAProxy (reads: 5433, writes: 5432, stats: 8404)
- Database: ecommerce

### Task 3: Nginx Reverse Proxy
- **Proxy:** nginx (157.180.118.98)
- **Backends:** app-1, app-2
- DDoS protection, load balancing, health checks
- Port: 8000

### Task 4: Asterisk VoIP
- **PBX Servers:** asterisk-1, asterisk-2
- **Load Balancer:** Kamailio (80/20 split)
- **Testing:** SIPp tool

## Current Status

### ✅ Implemented (Following Infrastructure Pattern)
- **Common role** - Base system setup for all servers
- **MariaDB Primary + Replica** - Complete replication setup
  - ✅ Unified Ansible playbooks
  - ✅ Docker test environment
  - ✅ Automated test script (13 tests)
  - ✅ Works identically in Docker and production
- **Infrastructure Pattern** - Reusable template and documentation
  - See `INFRASTRUCTURE_PATTERN.md` for details
  - Template available in `ansible/templates/component-template/`

### 🔄 To Do (Apply Infrastructure Pattern)
- PostgreSQL Primary + 2 Replicas
- HAProxy load balancer for PostgreSQL
- Nginx reverse proxy
- Application servers
- Asterisk VoIP servers
- Kamailio load balancer

## Common Commands

### Testing (Following Infrastructure Pattern)

```bash
# Test MariaDB on Docker
cd ansible
./test-mariadb.sh docker

# Test MariaDB on production
./test-mariadb.sh prod

# Test both environments
./test-mariadb.sh all
```

### Deployment

```bash
# Deploy to Docker (test first!)
cd ansible
ansible-playbook -i inventory/hosts-docker-test.yml playbooks/mariadb.yml

# Deploy to production (after Docker tests pass)
ansible-playbook playbooks/mariadb.yml

# Dry run (check what would change)
ansible-playbook playbooks/mariadb.yml --check
```

### General Commands

```bash
# Test connectivity
ansible all -m ping

# Check disk space
ansible all -m shell -a "df -h"

# Run single role/playbook
ansible-playbook playbooks/mariadb-primary.yml
```

## VM Inventory

```
maria-primary       157.180.114.52
maria-replica       37.27.248.240
postgres-primary    46.62.207.138
postgres-replica-1  37.27.255.157
postgres-replica-2  65.21.148.130
nginx               157.180.118.98
app-1               37.27.203.40
app-2               46.62.196.149
asterisk-1          46.62.200.187
asterisk-2          95.216.205.250
asterisk-balancer   37.27.35.37
```

## Why Ansible?

Switched from Terraform to Ansible because:
- ✅ Better for configuration management (VMs already exist)
- ✅ Drift detection - Detects and fixes manual changes
- ✅ Idempotent - Safe to run multiple times
- ✅ Incremental updates - Changes only what's needed
- ✅ Native modules - mysql_user, mysql_db, service, etc.

See `docs/archived/TERRAFORM-VS-ANSIBLE.md` for detailed comparison.

## Troubleshooting

```bash
# Test SSH
ssh maria-primary

# Check inventory
ansible-inventory --list

# Verbose output
ansible-playbook playbook.yml -vvv

# Syntax validation
ansible-playbook playbook.yml --syntax-check
```

## References

- [Ansible Documentation](https://docs.ansible.com/)
- [MariaDB Replication](https://mariadb.com/kb/en/setting-up-replication/)
- [PostgreSQL Streaming Replication](https://www.postgresql.org/docs/current/warm-standby.html)
- [HAProxy Configuration](https://www.haproxy.org/)
- [Nginx Load Balancing](https://docs.nginx.com/nginx/admin-guide/load-balancer/)
