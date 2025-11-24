# Ansible Quick Start - 5 Minutes to First Deployment

## Prerequisites

- Ansible installed: `pip3 install ansible` or `brew install ansible`
- SSH key at `~/.ssh/redi_test_key`
- Access to VMs from `VM hosts.txt`

## Step 1: Test Connection (30 seconds)

```bash
cd ansible

# Ping maria-primary server
ansible maria-primary -m ping
```

**Expected:**
```
maria-primary | SUCCESS => {
    "ping": "pong"
}
```

**If it fails:** Check SSH key and VM IP in `inventory/hosts.yml`

## Step 2: Dry Run (1 minute)

```bash
# See what would change WITHOUT making changes
ansible-playbook playbooks/maria-primary.yml --check
```

**You'll see:**
- Tasks that would run
- What would change
- Colored output (green=ok, yellow=changed)

## Step 3: Deploy MariaDB (2-3 minutes)

```bash
# Deploy for real!
ansible-playbook playbooks/maria-primary.yml
```

**Watch as it:**
1. ✅ Installs base packages
2. ✅ Creates testuser
3. ✅ Installs MariaDB
4. ✅ Configures MariaDB
5. ✅ Creates users and database

## Step 4: Verify (30 seconds)

```bash
# SSH to server
ssh maria-primary

# Check MariaDB
mysql -u app_user -papp_password voip_db -e "SHOW TABLES;"

# Should show: calls table
```

## Done! 🎉

You just:
- Configured a complete MariaDB server
- Using Infrastructure as Code
- In under 5 minutes

## What's Next?

### Change MariaDB Config

```bash
# 1. Edit variables
vim roles/mariadb-primary/defaults/main.yml
# Change: mariadb_max_connections: 1000

# 2. Apply
ansible-playbook playbooks/maria-primary.yml

# Done! Config updated, MariaDB restarted automatically
```

### Run Idempotency Test

```bash
# Run again
ansible-playbook playbooks/maria-primary.yml

# Notice: Nothing changes (already in correct state)
```

### Deploy to All Servers

```bash
# Once you have more roles configured
ansible-playbook playbooks/site.yml
```

## Common Commands

```bash
# Test connection
ansible all -m ping

# Dry run
ansible-playbook playbook.yml --check

# Deploy
ansible-playbook playbook.yml

# Deploy with verbose output
ansible-playbook playbook.yml -v

# Run specific tags only
ansible-playbook playbook.yml --tags mariadb_config

# Check disk space on all servers
ansible all -m shell -a "df -h"
```

## Troubleshooting

### Can't connect to server

```bash
# Test SSH manually
ssh -i ~/.ssh/redi_test_key root@maria-primary

# Check inventory
cat inventory/hosts.yml
```

### Playbook fails

```bash
# Run with verbose output to see details
ansible-playbook playbook.yml -vv

# Check syntax
ansible-playbook playbook.yml --syntax-check
```

## File Structure Quick Reference

```
ansible/
├── ansible.cfg                 # Ansible settings
├── inventory/hosts.yml         # Your servers
├── roles/
│   ├── common/                 # Base setup
│   │   └── tasks/main.yml     # What to do
│   └── mariadb-primary/
│       ├── tasks/main.yml     # Install/config tasks
│       ├── defaults/main.yml  # Variables
│       └── templates/my.cnf.j2 # Config template
└── playbooks/
    └── maria-primary.yml      # Orchestration
```

**To modify behavior:**
- Edit `defaults/main.yml` - Change variables
- Edit `tasks/main.yml` - Add/modify tasks
- Edit `templates/*.j2` - Change config files

**Then run:**
```bash
ansible-playbook playbooks/maria-primary.yml
```

That's it! Read `ANSIBLE-BEGINNERS-GUIDE.md` for more details.
