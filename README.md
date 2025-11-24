# Infrastructure Configuration with Ansible

Automated configuration management for VoIP and database infrastructure using Ansible.

## Overview

This project uses **Ansible** to configure and manage:
- MariaDB Primary/Replica (replication setup)
- PostgreSQL Primary + 2 Replicas + HAProxy load balancer
- Nginx reverse proxy with DDoS protection
- Application servers
- Asterisk VoIP servers with load balancing

## Quick Start

### Prerequisites

- Ansible installed: `pip3 install ansible` or `brew install ansible`
- Docker installed (for local testing)
- SSH access to VMs configured in `~/.ssh/config`
- SSH key: `~/.ssh/redi_test_key`

### Option 1: Test Locally with Docker (Recommended)

```bash
# Start Docker containers
cd ansible
docker-compose up -d

# Deploy to Docker containers
ansible-playbook -i inventory/hosts-docker-test.yml playbooks/mariadb.yml

# Run tests
./test-mariadb.sh docker
```

### Option 2: Deploy to Production VMs

```bash
cd ansible

# Test connection
ansible maria-primary -m ping

# Deploy (dry run first)
ansible-playbook playbooks/mariadb.yml --check

# Deploy for real
ansible-playbook playbooks/mariadb.yml

# Verify
./test-mariadb.sh prod
```

## Directory Structure

```
.
├── ansible/                    # Ansible configuration (MAIN TOOL)
│   ├── inventory/             # VM definitions
│   │   ├── hosts.yml          # Production inventory
│   │   └── hosts-docker-test.yml  # Docker test inventory
│   ├── roles/                 # Reusable configurations
│   │   ├── common/            # Base setup for all servers
│   │   ├── mariadb-primary/   # MariaDB primary
│   │   ├── mariadb-replica/   # MariaDB replica
│   │   ├── postgres-*/        # PostgreSQL servers
│   │   ├── haproxy/           # HAProxy load balancer
│   │   ├── nginx/             # Nginx reverse proxy
│   │   ├── app/               # Application servers
│   │   ├── asterisk/          # Asterisk VoIP backends
│   │   └── asterisk-balancer/ # Asterisk load balancer
│   ├── playbooks/             # Deployment playbooks
│   └── test-*.sh              # Automated test scripts
│
├── docker-compose.yml         # Docker containers for local testing
├── docker-base/               # Base VM simulation image
│
├── docs/                      # Documentation
│   ├── NGINX-DDOS-PROTECTION.md
│   ├── ASTERISK-GUIDE.md
│   └── archived/              # Previous approaches (reference)
│
├── INFRASTRUCTURE_PATTERN.md  # Development pattern guide
├── QUICK_PATTERN_REFERENCE.md # Quick reference card
└── VM hosts.txt               # Production VM IPs
```

## Project Tasks

### Task 1: MariaDB Replication
- **Primary:** maria-primary (157.180.114.52)
- **Replica:** maria-replica (37.27.248.240)
- Binary log replication, read-only replica
- Database: voip_db

### Task 2: PostgreSQL Load Balancing
- **Primary:** postgres-primary (46.62.207.138)
- **Replicas:** postgres-replica-1 (37.27.255.157), postgres-replica-2 (65.21.148.130)
- **Load Balancer:** HAProxy on postgres-balancer (reads: 5433, writes: 5432)
- Database: ecommerce

### Task 3: Nginx Reverse Proxy
- **Proxy:** nginx (157.180.118.98)
- **Backends:** app-1 (37.27.203.40), app-2 (46.62.196.149)
- DDoS protection, load balancing, health checks
- Port: 8000

### Task 4: Asterisk VoIP
- **PBX Servers:** asterisk-1 (46.62.200.187), asterisk-2 (95.216.205.250)
- **Load Balancer:** asterisk-balancer (37.27.35.37) - 80/20 traffic split
- Call behavior: 12% busy, 33% no answer, 55% answer with tt-monkeys

## Current Status

### Implemented
- MariaDB Primary + Replica replication
- PostgreSQL Primary + 2 Replicas + HAProxy
- Nginx reverse proxy with DDoS protection
- Asterisk VoIP with load balancing
- Docker test environment for all components
- Automated test scripts

## Documentation

- **[INFRASTRUCTURE_PATTERN.md](INFRASTRUCTURE_PATTERN.md)** - Development pattern (test locally, deploy to production)
- **[QUICK_PATTERN_REFERENCE.md](QUICK_PATTERN_REFERENCE.md)** - Quick reference card
- **[ansible/README.md](ansible/README.md)** - Ansible setup reference
- **[docs/NGINX-DDOS-PROTECTION.md](docs/NGINX-DDOS-PROTECTION.md)** - Nginx DDoS configuration
- **[docs/ASTERISK-GUIDE.md](docs/ASTERISK-GUIDE.md)** - VoIP configuration guide

## Common Commands

### Testing

```bash
cd ansible

# Test specific component
./test-mariadb.sh docker      # Test MariaDB on Docker
./test-mariadb.sh prod        # Test MariaDB on production
./test-postgres.sh docker     # Test PostgreSQL on Docker
./test-nginx.sh docker        # Test Nginx on Docker
```

### Deployment

```bash
cd ansible

# Deploy to Docker
ansible-playbook -i inventory/hosts-docker-test.yml playbooks/mariadb.yml

# Deploy to production
ansible-playbook playbooks/mariadb.yml

# Dry run
ansible-playbook playbooks/mariadb.yml --check
```

### Docker Management

```bash
# Start all containers
docker-compose up -d

# Start specific containers
docker-compose up -d maria-primary-test maria-replica-test

# View logs
docker-compose logs -f maria-primary-test

# Stop all
docker-compose down
```

## VM Inventory

| Server | IP | Purpose |
|--------|-----|---------|
| maria-primary | 157.180.114.52 | MariaDB Primary |
| maria-replica | 37.27.248.240 | MariaDB Replica |
| postgres-primary | 46.62.207.138 | PostgreSQL Primary |
| postgres-replica-1 | 37.27.255.157 | PostgreSQL Replica |
| postgres-replica-2 | 65.21.148.130 | PostgreSQL Replica / HAProxy |
| nginx | 157.180.118.98 | Nginx Reverse Proxy |
| app-1 | 37.27.203.40 | Application Server |
| app-2 | 46.62.196.149 | Application Server |
| asterisk-1 | 46.62.200.187 | Asterisk PBX (80%) |
| asterisk-2 | 95.216.205.250 | Asterisk PBX (20%) |
| asterisk-balancer | 37.27.35.37 | Asterisk Load Balancer |

## Troubleshooting

```bash
# Test SSH connectivity
ansible all -m ping

# Verbose playbook output
ansible-playbook playbook.yml -vvv

# Check inventory
ansible-inventory --list

# SSH directly to server
ssh maria-primary
```

## References

- [Ansible Documentation](https://docs.ansible.com/)
- [MariaDB Replication](https://mariadb.com/kb/en/setting-up-replication/)
- [PostgreSQL Streaming Replication](https://www.postgresql.org/docs/current/warm-standby.html)
- [HAProxy Configuration](https://www.haproxy.org/)
- [Nginx Load Balancing](https://docs.nginx.com/nginx/admin-guide/load-balancer/)
- [Asterisk PBX](https://www.asterisk.org/get-started/)
