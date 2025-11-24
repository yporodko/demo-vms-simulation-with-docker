# Ansible Infrastructure Management

This directory contains Ansible playbooks and roles for managing your infrastructure.

## What's Here

### Quick Start

**New to Ansible?** → Read `QUICK-START.md` (5 minutes)

**Want to learn more?** → Read `ANSIBLE-BEGINNERS-GUIDE.md` (comprehensive guide)

### Structure

```
ansible/
├── README.md                      # You are here
├── QUICK-START.md                 # 5-minute getting started
├── ANSIBLE-BEGINNERS-GUIDE.md     # Complete learning guide
├── ansible.cfg                    # Ansible configuration
├── inventory/
│   └── hosts.yml                  # Your VMs (from VM hosts.txt)
├── roles/
│   ├── common/                    # Base system setup (all servers)
│   └── mariadb-primary/           # MariaDB primary server
└── playbooks/
    ├── maria-primary.yml          # Deploy maria-primary
    └── site.yml                   # Deploy everything
```

## Quick Commands

```bash
# Test connection
ansible maria-primary -m ping

# Deploy MariaDB (dry run)
ansible-playbook playbooks/maria-primary.yml --check

# Deploy MariaDB (for real)
ansible-playbook playbooks/maria-primary.yml

# Deploy everything
ansible-playbook playbooks/site.yml
```

## What We Converted from Terraform

### From Terraform

```
terraform/
└── modules/maria-primary/
    - Uses null_resource + SSH provisioners
    - Runs shell scripts remotely
    - No drift detection
    - Destroys/recreates on changes
```

### To Ansible

```
ansible/
└── roles/mariadb-primary/
    - Uses native Ansible modules (apt, service, mysql_user, etc.)
    - Idempotent by design
    - Automatic drift detection
    - Incremental updates
```

## Comparison

| Feature | Terraform (old) | Ansible (new) |
|---------|----------------|---------------|
| Install MariaDB | Shell script | `apt` module |
| Create MySQL user | Shell + SQL | `mysql_user` module |
| Config management | Copy files | `template` module |
| Drift detection | ❌ None | ✅ Automatic |
| Idempotency | ⚠️ Manual | ✅ Built-in |
| Updates | Destroy/recreate | Update only changed |

## Currently Implemented

✅ **Common role** (`roles/common/`)
- Install base packages
- Create testuser
- Configure SSH

✅ **MariaDB Primary role** (`roles/mariadb-primary/`)
- Install MariaDB 10.11
- Configure replication
- Create users (repl, app_user)
- Create voip_db database
- Load initial data

## To Do

⬜ Create `mariadb-replica` role
⬜ Create `postgres-primary` role
⬜ Create `postgres-replica` role
⬜ Create `postgres-balancer` role (HAProxy)
⬜ Create `nginx` role
⬜ Create `app-server` role
⬜ Create `asterisk` role
⬜ Create `kamailio` role (SIP load balancer)

## How to Add New Service

### Example: Create maria-replica role

```bash
# 1. Create role structure
mkdir -p roles/maria-replica/{tasks,handlers,templates,files,defaults}

# 2. Copy from maria-primary as template
cp -r roles/mariadb-primary/* roles/maria-replica/

# 3. Modify for replica
vim roles/maria-replica/defaults/main.yml
# Change: mariadb_server_id: 2
# Change: mariadb_read_only: 1

# 4. Update tasks
vim roles/maria-replica/tasks/main.yml
# Add replication setup tasks

# 5. Create playbook
cat > playbooks/maria-replica.yml <<EOF
---
- name: Configure MariaDB Replica
  hosts: maria-replica
  roles:
    - common
    - maria-replica
EOF

# 6. Test
ansible-playbook playbooks/maria-replica.yml --check

# 7. Apply
ansible-playbook playbooks/maria-replica.yml
```

## Best Practices

### 1. Always Use Check Mode First

```bash
ansible-playbook playbook.yml --check     # Dry run
ansible-playbook playbook.yml --check --diff # Show differences
ansible-playbook playbook.yml              # Apply
```

### 2. Use Tags for Selective Runs

```bash
# Only update config files
ansible-playbook playbook.yml --tags config

# Only manage users
ansible-playbook playbook.yml --tags users
```

### 3. Version Control

```bash
git add ansible/
git commit -m "Add maria-replica role"
```

### 4. Test Locally First

Before applying to real VMs, you can test on Docker:

```bash
# Start Docker container
docker run -d --name test-maria -p 2222:22 vm-base:debian12

# Add to inventory
# ...

# Test playbook
ansible-playbook -i test-inventory playbook.yml
```

## Configuration Variables

### Global Variables

Set in `inventory/hosts.yml`:

```yaml
all:
  vars:
    ansible_user: root
    ansible_ssh_private_key_file: ~/.ssh/redi_test_key
```

### Role Variables

Set in `roles/*/defaults/main.yml`:

```yaml
# roles/mariadb-primary/defaults/main.yml
mariadb_max_connections: 500
mariadb_server_id: 1
```

### Override in Playbook

```yaml
# playbooks/maria-primary.yml
- hosts: maria-primary
  roles:
    - role: mariadb-primary
      vars:
        mariadb_max_connections: 1000  # Override!
```

### Override on Command Line

```bash
ansible-playbook playbook.yml -e "mariadb_max_connections=1000"
```

## Troubleshooting

### Check Ansible Version

```bash
ansible --version
# Should be >= 2.9
```

### Install Ansible

```bash
# macOS
brew install ansible

# Linux
sudo apt-get install ansible

# Python
pip3 install ansible
```

### Test Connectivity

```bash
# Ping all servers
ansible all -m ping

# Check if Ansible can gather facts
ansible maria-primary -m setup
```

### Verbose Output

```bash
ansible-playbook playbook.yml -v    # Verbose
ansible-playbook playbook.yml -vv   # More verbose
ansible-playbook playbook.yml -vvv  # Debug mode
```

### Validate Syntax

```bash
ansible-playbook playbook.yml --syntax-check
```

## Useful Ad-Hoc Commands

```bash
# Check MariaDB status
ansible maria-primary -m service -a "name=mariadb"

# Check disk space
ansible all -m shell -a "df -h"

# Get system facts
ansible maria-primary -m setup

# Restart service
ansible maria-primary -m service -a "name=mariadb state=restarted"

# Run any command
ansible maria-primary -m shell -a "mysql --version"

# Copy file
ansible maria-primary -m copy -a "src=file.txt dest=/tmp/"
```

## Documentation Links

- [Ansible Documentation](https://docs.ansible.com/)
- [Ansible Modules](https://docs.ansible.com/ansible/latest/collections/index_module.html)
- [Best Practices](https://docs.ansible.com/ansible/latest/user_guide/playbooks_best_practices.html)
- [MySQL Modules](https://docs.ansible.com/ansible/latest/collections/community/mysql/index.html)

## Getting Help

1. **Read guides in this directory:**
   - `QUICK-START.md` - Quick 5-minute intro
   - `ANSIBLE-BEGINNERS-GUIDE.md` - Comprehensive guide

2. **Check Ansible docs:**
   ```bash
   ansible-doc apt        # Documentation for apt module
   ansible-doc mysql_user # Documentation for mysql_user module
   ```

3. **Verbose output:**
   ```bash
   ansible-playbook playbook.yml -vvv
   ```

4. **Dry run with diff:**
   ```bash
   ansible-playbook playbook.yml --check --diff
   ```

## Summary

You now have:
- ✅ Complete Ansible setup
- ✅ Working maria-primary role
- ✅ Comprehensive guides
- ✅ Ready to deploy

**Next steps:**
1. Read `QUICK-START.md`
2. Test: `ansible maria-primary -m ping`
3. Deploy: `ansible-playbook playbooks/maria-primary.yml`
4. Expand to other services

Happy automating! 🚀
