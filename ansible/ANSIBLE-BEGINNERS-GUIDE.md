# Ansible for Beginners - Complete Guide

## What is Ansible?

Ansible is a tool that automates:
- Installing software on servers
- Configuring services
- Managing files and settings
- Ensuring servers are in the correct state

**Key benefit:** You describe what you want, Ansible makes it happen!

## Why Ansible?

✅ **Simple** - Uses YAML (human-readable)
✅ **Agentless** - No software to install on servers, just SSH
✅ **Idempotent** - Safe to run multiple times
✅ **Powerful** - Can manage thousands of servers

## How Ansible Works

```
You (on your laptop)
    ↓
ansible-playbook command
    ↓
Reads inventory (which servers?)
    ↓
Reads playbook (what to do?)
    ↓
SSH to servers
    ↓
Executes tasks
    ↓
Reports results
```

## Key Concepts

### 1. Inventory

**What:** List of your servers

**Example:** `inventory/hosts.yml`
```yaml
all:
  children:
    mariadb:
      hosts:
        maria-primary:
          ansible_host: 157.180.114.52
```

**Translation:** "I have a group called 'mariadb' with a server 'maria-primary' at this IP"

### 2. Playbook

**What:** Instructions for what to do on servers

**Example:** `playbooks/maria-primary.yml`
```yaml
- name: Configure MariaDB
  hosts: maria-primary    # Which server?
  roles:
    - mariadb-primary     # What to do?
```

**Translation:** "On server maria-primary, apply the mariadb-primary role"

### 3. Role

**What:** Collection of tasks organized by purpose

**Structure:**
```
roles/mariadb-primary/
├── tasks/       # What to do (install packages, copy files)
├── handlers/    # Actions triggered by changes (restart services)
├── templates/   # Config files with variables
├── files/       # Static files to copy
└── defaults/    # Default variables
```

### 4. Task

**What:** Single action to perform

**Example:**
```yaml
- name: Install MariaDB
  apt:
    name: mariadb-server
    state: present
```

**Translation:** "Make sure mariadb-server package is installed"

### 5. Module

**What:** Pre-built Ansible commands

**Common modules:**
- `apt` - Install packages
- `service` - Start/stop services
- `copy` - Copy files
- `template` - Copy files with variables
- `mysql_user` - Create MySQL users
- `mysql_db` - Create MySQL databases

## Your Ansible Setup

### Directory Structure

```
ansible/
├── ansible.cfg             # Ansible settings
├── inventory/
│   └── hosts.yml          # Your VMs
├── roles/
│   ├── common/            # Base setup (all servers)
│   └── mariadb-primary/   # MariaDB specific
└── playbooks/
    ├── maria-primary.yml  # Deploy maria-primary
    └── site.yml           # Deploy everything
```

### Inventory Explained

```yaml
# inventory/hosts.yml
all:                          # Root group
  children:                   # Sub-groups
    mariadb:                  # Group name
      hosts:                  # List of servers
        maria-primary:        # Server name
          ansible_host: 157.180.114.52  # IP address
```

**How to use groups:**
```bash
# Run on all mariadb servers
ansible mariadb -m ping

# Run on all servers
ansible all -m ping

# Run on specific server
ansible maria-primary -m ping
```

### Role Structure Explained

#### tasks/main.yml
**Purpose:** List of things to do

```yaml
- name: Install MariaDB        # What this task does
  apt:                         # Module to use
    name: mariadb-server       # Package name
    state: present             # Desired state
  tags: mariadb                # Tag for selective running
```

#### handlers/main.yml
**Purpose:** Actions that run only if something changed

```yaml
- name: restart mariadb
  service:
    name: mariadb
    state: restarted
```

**How it works:**
```yaml
# In tasks:
- name: Copy config
  template:
    src: my.cnf.j2
    dest: /etc/mysql/my.cnf
  notify: restart mariadb    # Trigger the handler!
```

**Flow:**
1. Task runs, config changes
2. Handler is notified
3. At the end of playbook, handler runs once
4. MariaDB restarts

#### templates/my.cnf.j2
**Purpose:** Config files with variables

```ini
# Can use variables from defaults/main.yml
max_connections = {{ mariadb_max_connections }}
server_id = {{ mariadb_server_id }}
```

#### defaults/main.yml
**Purpose:** Default variable values

```yaml
mariadb_max_connections: 500
mariadb_server_id: 1
```

**Override in playbook:**
```yaml
- name: Configure MariaDB
  hosts: maria-primary
  roles:
    - role: mariadb-primary
      vars:
        mariadb_max_connections: 1000  # Override!
```

## Common Commands

### Test Connection to Servers

```bash
cd ansible

# Ping all servers
ansible all -m ping

# Ping specific server
ansible maria-primary -m ping

# Ping group
ansible mariadb -m ping
```

**Output:**
```
maria-primary | SUCCESS => {
    "ping": "pong"
}
```

### Run Playbook (Dry Run)

```bash
# See what would change WITHOUT actually changing anything
ansible-playbook playbooks/maria-primary.yml --check

# See differences in files
ansible-playbook playbooks/maria-primary.yml --check --diff
```

### Run Playbook (For Real)

```bash
# Apply configuration
ansible-playbook playbooks/maria-primary.yml

# With extra verbosity (debugging)
ansible-playbook playbooks/maria-primary.yml -v

# Even more verbose
ansible-playbook playbooks/maria-primary.yml -vv
```

### Run Specific Tags

```bash
# Only run tasks tagged with 'mariadb_config'
ansible-playbook playbooks/maria-primary.yml --tags mariadb_config

# Skip certain tags
ansible-playbook playbooks/maria-primary.yml --skip-tags mariadb_users
```

### Run Ad-Hoc Commands

```bash
# Check disk space on all servers
ansible all -m shell -a "df -h"

# Check MariaDB version
ansible maria-primary -m shell -a "mysql --version"

# Restart MariaDB
ansible maria-primary -m service -a "name=mariadb state=restarted"

# Copy a file
ansible maria-primary -m copy -a "src=/local/file dest=/remote/file"
```

## Step-by-Step: First Run

### 1. Verify Inventory

```bash
cd ansible

# List all hosts
ansible-inventory --list

# Show specific host
ansible-inventory --host maria-primary
```

### 2. Test SSH Connection

```bash
# Ping the server
ansible maria-primary -m ping
```

**Expected output:**
```
maria-primary | SUCCESS => {
    "ping": "pong"
}
```

**If it fails:**
```bash
# Test SSH manually
ssh -i ~/.ssh/redi_test_key root@157.180.114.52

# Check ansible.cfg has correct key
cat ansible.cfg | grep private_key
```

### 3. Dry Run

```bash
# See what would change
ansible-playbook playbooks/maria-primary.yml --check
```

**Output shows:**
```
TASK [mariadb-primary : Install MariaDB server] *****
changed: [maria-primary]     ← Would install

TASK [mariadb-primary : Create replication user] ****
changed: [maria-primary]     ← Would create
```

### 4. Apply for Real

```bash
ansible-playbook playbooks/maria-primary.yml
```

**Watch the output:**
```
PLAY [Configure MariaDB Primary Server] **************

TASK [Gathering Facts] *******************************
ok: [maria-primary]

TASK [common : Update apt cache] *********************
changed: [maria-primary]

TASK [common : Install base packages] ****************
changed: [maria-primary]

...

PLAY RECAP *******************************************
maria-primary : ok=15 changed=10 unreachable=0 failed=0
```

**Status meanings:**
- `ok` - Task ran, no changes needed (already correct)
- `changed` - Task ran, made changes
- `failed` - Task failed
- `unreachable` - Can't connect to server

### 5. Verify Results

```bash
# SSH to server
ssh root@maria-primary

# Check MariaDB
systemctl status mariadb

# Test connection
mysql -u app_user -papp_password voip_db -e "SHOW TABLES;"

# Exit
exit
```

### 6. Run Again (Idempotency Test)

```bash
ansible-playbook playbooks/maria-primary.yml
```

**Now should see:**
```
PLAY RECAP *******************************************
maria-primary : ok=15 changed=0 unreachable=0 failed=0
                        ↑
                   Nothing changed! Already correct state.
```

## Practical Examples

### Example 1: Change MariaDB Config

```bash
# 1. Edit the defaults
vim roles/mariadb-primary/defaults/main.yml
# Change: mariadb_max_connections: 1000

# 2. Preview changes
ansible-playbook playbooks/maria-primary.yml --check --diff

# 3. Apply
ansible-playbook playbooks/maria-primary.yml

# 4. Verify
ansible maria-primary -m shell -a "mysql -u root -e 'SHOW VARIABLES LIKE \"max_connections\";'"
```

**What happens:**
1. Ansible detects config file changed
2. Copies new config to server
3. Triggers handler
4. Restarts MariaDB
5. Done!

### Example 2: Add New User

```bash
# 1. Add task to role
vim roles/mariadb-primary/tasks/main.yml
```

```yaml
# Add this task:
- name: Create additional user
  mysql_user:
    name: newuser
    password: newpass
    priv: "*.*:SELECT"
    state: present
  tags: mariadb_users
```

```bash
# 2. Run just this task
ansible-playbook playbooks/maria-primary.yml --tags mariadb_users
```

### Example 3: Update All Servers

```bash
# Run base configuration on all servers
ansible-playbook playbooks/site.yml
```

## Debugging

### Check What Ansible Sees

```bash
# Show inventory
ansible-inventory --graph

# Show variables for a host
ansible-inventory --host maria-primary --yaml
```

### Run with Verbosity

```bash
# Normal
ansible-playbook playbooks/maria-primary.yml

# Verbose
ansible-playbook playbooks/maria-primary.yml -v

# Very verbose (shows module arguments)
ansible-playbook playbooks/maria-primary.yml -vv

# Debug level (shows everything)
ansible-playbook playbooks/maria-primary.yml -vvv
```

### Check Syntax

```bash
# Validate playbook syntax
ansible-playbook playbooks/maria-primary.yml --syntax-check
```

### Debug Variables

```yaml
# Add to playbook:
- name: Debug variables
  debug:
    var: mariadb_max_connections
```

### Step Through Tasks

```bash
# Execute one task at a time, ask before each
ansible-playbook playbooks/maria-primary.yml --step
```

## Best Practices

### 1. Always Use Check Mode First

```bash
# Never run blind!
ansible-playbook playbook.yml --check
ansible-playbook playbook.yml          # If OK, then apply
```

### 2. Use Version Control

```bash
cd ansible
git add .
git commit -m "Increase max_connections to 1000"
```

### 3. Use Tags

```yaml
tasks:
  - name: Install MariaDB
    apt:
      name: mariadb-server
    tags:
      - mariadb
      - packages
```

Run specific parts:
```bash
ansible-playbook playbook.yml --tags packages
```

### 4. Keep Secrets Safe

Don't commit passwords! Use Ansible Vault:

```bash
# Create encrypted file
ansible-vault create secrets.yml

# Edit encrypted file
ansible-vault edit secrets.yml

# Use in playbook
ansible-playbook playbook.yml --ask-vault-pass
```

### 5. Test in Docker First

```bash
# Just like we did with Terraform!
# Test configuration on local Docker first
ansible-playbook -i docker-inventory playbook.yml

# Then apply to real VMs
ansible-playbook -i inventory/hosts.yml playbook.yml
```

## Quick Reference Card

| Task | Command |
|------|---------|
| Test connection | `ansible maria-primary -m ping` |
| Run playbook (dry run) | `ansible-playbook playbook.yml --check` |
| Run playbook | `ansible-playbook playbook.yml` |
| Run with tags | `ansible-playbook playbook.yml --tags mariadb` |
| Verbose output | `ansible-playbook playbook.yml -vv` |
| List inventory | `ansible-inventory --list` |
| Ad-hoc command | `ansible maria-primary -m shell -a "command"` |
| Check syntax | `ansible-playbook playbook.yml --syntax-check` |

## Common Errors and Solutions

### Error: "Permission denied (publickey)"

**Problem:** SSH key not working

**Solution:**
```bash
# Check ansible.cfg has correct key
cat ansible.cfg | grep private_key

# Test SSH manually
ssh -i ~/.ssh/redi_test_key root@157.180.114.52
```

### Error: "Failed to connect to the host"

**Problem:** Server unreachable

**Solution:**
```bash
# Ping server
ping 157.180.114.52

# Check firewall allows SSH
# Check inventory has correct IP
```

### Error: "Could not find imported module"

**Problem:** Module not installed on remote server

**Solution:**
```yaml
# Add to common role:
- name: Install Python dependencies
  apt:
    name: python3-pymysql
    state: present
```

## Next Steps

### Your First Tasks

1. **Test connection:**
   ```bash
   cd ansible
   ansible maria-primary -m ping
   ```

2. **Dry run:**
   ```bash
   ansible-playbook playbooks/maria-primary.yml --check
   ```

3. **Apply configuration:**
   ```bash
   ansible-playbook playbooks/maria-primary.yml
   ```

4. **Verify:**
   ```bash
   ssh maria-primary
   mysql -u app_user -papp_password voip_db -e "SHOW TABLES;"
   ```

### Learning Path

1. ✅ Understand inventory
2. ✅ Run simple playbook (maria-primary)
3. ⬜ Modify variables
4. ⬜ Add new tasks
5. ⬜ Create new role (maria-replica)
6. ⬜ Use templates
7. ⬜ Use handlers
8. ⬜ Multi-server orchestration

## Summary

**Ansible is:**
- Simple YAML files describing desired state
- Agentless (uses SSH)
- Idempotent (safe to run multiple times)
- Powerful (manages thousands of servers)

**Basic workflow:**
1. Edit inventory (which servers?)
2. Edit playbook/role (what to do?)
3. Dry run (`--check`)
4. Apply
5. Verify
6. Commit to git

**You're ready to use Ansible!** 🚀
