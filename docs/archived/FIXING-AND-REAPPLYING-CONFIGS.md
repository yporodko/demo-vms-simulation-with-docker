# Fixing and Reapplying Configurations

## The Scenario

You applied a config, and it broke something. How do you fix it and apply the corrected version?

## How It Works

Terraform uses **triggers** (file checksums) to detect when to re-provision:

```hcl
# In terraform/modules/maria-primary/main.tf
resource "null_resource" "maria_primary" {
  triggers = {
    install_script_hash = filemd5("provisioning/maria-primary/install.sh")
    config_hash         = filemd5("provisioning/maria-primary/configure.sh")
    my_cnf_hash         = filemd5("maria-primary/config/my.cnf")
    voip_db_sql_hash    = filemd5("maria-primary/init/voip_db.sql")
  }
}
```

**Key insight:** When ANY of these files change, Terraform will re-provision!

## Workflow: Fix and Reapply

### Example Problem

You applied a config with wrong `max_connections`:

```ini
# maria-primary/config/my.cnf (BROKEN)
max_connections = 50  # TOO LOW! MariaDB crashes
```

### Step 1: Fix the Source File

```bash
# Edit the config file locally
vim maria-primary/config/my.cnf

# Change to correct value
max_connections = 500
```

### Step 2: Run Terraform Plan

```bash
cd terraform/environments/docker
terraform plan
```

**Output:**
```
Terraform will perform the following actions:

  # module.maria_primary.null_resource.maria_primary must be replaced
-/+ resource "null_resource" "maria_primary" {
      ~ triggers = {
          ~ my_cnf_hash = "old_checksum_123" -> "new_checksum_456"
            # (3 unchanged attributes)
        }
    }

Plan: 1 to add, 0 to change, 1 to destroy.
```

**What this means:**
- Terraform detected the file change (checksum changed)
- Will destroy old resource
- Will create new one
- Will re-run ALL provisioning scripts with new config

### Step 3: Apply the Fix

```bash
terraform apply
```

**What happens:**
1. Uploads all provisioning scripts again
2. Uploads the FIXED my.cnf
3. Runs install.sh
4. Runs configure.sh (which copies my.cnf to /etc/mysql/)
5. MariaDB gets configured with correct settings

### Step 4: Verify

```bash
# SSH to container/VM
ssh -i ~/.ssh/redi_test_key -p 2201 root@localhost

# Check the config
grep max_connections /etc/mysql/mariadb.conf.d/99-custom.cnf
# Output: max_connections = 500  ✓ FIXED!

# Check if MariaDB is running
systemctl status mariadb
# OR (in Docker)
service mariadb status
```

## Complete Example Walkthrough

### Scenario: Bad Configuration Breaks MariaDB

#### Initial Bad Config

```bash
# You make a typo in my.cnf
cat maria-primary/config/my.cnf
```

```ini
[mysqld]
server_id = 1
max_connections = abc  # TYPO! Should be a number
```

#### Apply the Bad Config

```bash
cd terraform/environments/docker
terraform apply
```

**Result:** MariaDB fails to start due to bad config!

#### Diagnose the Problem

```bash
# SSH to container
ssh -i ~/.ssh/redi_test_key -p 2201 root@localhost

# Check MariaDB status
service mariadb status
# Output: Failed!

# Check logs
tail -f /var/log/mysql/error.log
# Output: Error: Invalid value 'abc' for max_connections
```

#### Fix the Config

```bash
# Exit from container
exit

# Fix the config file locally
vim maria-primary/config/my.cnf
```

```ini
[mysqld]
server_id = 1
max_connections = 500  # FIXED!
```

#### Reapply

```bash
# Check what will change
terraform plan
# Output: Will replace null_resource.maria_primary (my_cnf_hash changed)

# Apply the fix
terraform apply
# Output: Provisioning... Done!
```

#### Verify the Fix

```bash
# SSH again
ssh -i ~/.ssh/redi_test_key -p 2201 root@localhost

# Check config
cat /etc/mysql/mariadb.conf.d/99-custom.cnf
# Output: max_connections = 500  ✓

# Check MariaDB
service mariadb status
# Output: Running  ✓

# Test connection
mysql -u root -e "SHOW VARIABLES LIKE 'max_connections';"
# Output: max_connections | 500  ✓
```

## Different Types of Fixes

### 1. Fix Configuration File

**What to edit:**
- `maria-primary/config/my.cnf`
- `maria-primary/init/voip_db.sql`

**How:**
```bash
vim maria-primary/config/my.cnf
# Make changes
terraform apply
```

**Trigger:** `my_cnf_hash` changes → re-provision

### 2. Fix Provisioning Script

**What to edit:**
- `provisioning/maria-primary/install.sh`
- `provisioning/maria-primary/configure.sh`
- `provisioning/common/base-install.sh`

**How:**
```bash
vim provisioning/maria-primary/configure.sh
# Fix the script
terraform apply
```

**Trigger:** `maria_config_hash` changes → re-provision

### 3. Fix Both

```bash
# Fix config file
vim maria-primary/config/my.cnf

# Fix provisioning script
vim provisioning/maria-primary/configure.sh

# Apply both
terraform apply
```

**Trigger:** Both hashes change → re-provision with all fixes

## Force Re-provisioning (Manual Trigger)

### When to Use

Sometimes you need to re-provision even if files haven't changed:

- Someone made manual changes to the VM
- You want to ensure clean state
- Previous provisioning failed midway

### Method 1: Taint the Resource

```bash
# Mark resource for recreation
terraform taint module.maria_primary.null_resource.maria_primary

# Next apply will recreate it
terraform apply
```

**What happens:**
- Terraform marks resource as "tainted"
- Next `apply` will destroy and recreate
- Re-runs all provisioning

### Method 2: Destroy and Recreate

```bash
# Destroy specific resource
terraform destroy -target=module.maria_primary.null_resource.maria_primary

# Recreate it
terraform apply
```

**What happens:**
- Destroys the null_resource
- Removes from state
- Next apply recreates it fresh

### Method 3: Touch a File (Trigger Change)

```bash
# Make a trivial change to trigger re-provision
echo "# Force update" >> provisioning/maria-primary/configure.sh

# Remove it
git checkout provisioning/maria-primary/configure.sh

# Or just update timestamp
touch provisioning/maria-primary/configure.sh

terraform apply
```

**What happens:**
- File timestamp/content changes
- Checksum changes
- Terraform re-provisions

## Rollback to Previous Version

### Using Git

```bash
# View commit history
git log --oneline maria-primary/config/my.cnf

# Revert to previous version
git checkout HEAD~1 -- maria-primary/config/my.cnf

# Apply the old (working) version
terraform apply
```

### Version Control Best Practice

```bash
# Before making changes
git add .
git commit -m "Working MariaDB config"

# Make changes
vim maria-primary/config/my.cnf
terraform apply

# Breaks? Rollback
git checkout HEAD -- maria-primary/config/my.cnf
terraform apply
```

## Testing Before Applying to VMs

### Always Test in Docker First!

```bash
# 1. Make changes
vim maria-primary/config/my.cnf

# 2. Test in Docker
cd terraform/environments/docker
terraform apply

# 3. Verify it works
ssh -i ~/.ssh/redi_test_key -p 2201 root@localhost
service mariadb status
mysql -u root -e "SELECT 1;"

# 4. If good, apply to VM
cd ../vm
terraform apply
```

### Create Test Script

```bash
#!/bin/bash
# test-maria-primary.sh

HOST=$1
PORT=${2:-3306}

echo "Testing MariaDB on $HOST:$PORT..."

# Test connection
if mysql -h "$HOST" -P "$PORT" -u app_user -papp_password -e "SELECT 1;" &>/dev/null; then
    echo "✓ Connection successful"
else
    echo "✗ Connection failed"
    exit 1
fi

# Test database
if mysql -h "$HOST" -P "$PORT" -u app_user -papp_password voip_db -e "SHOW TABLES;" &>/dev/null; then
    echo "✓ Database exists"
else
    echo "✗ Database missing"
    exit 1
fi

# Test replication user
if mysql -h "$HOST" -P "$PORT" -u repl -preplpass -e "SELECT 1;" &>/dev/null; then
    echo "✓ Replication user works"
else
    echo "✗ Replication user failed"
    exit 1
fi

echo "✓ All tests passed!"
```

**Usage:**
```bash
# After provisioning
./test-maria-primary.sh localhost 3306        # Docker
./test-maria-primary.sh 157.180.114.52 3306   # VM
```

## Incremental Changes

### Problem

Terraform's approach is "destroy and recreate", which can cause downtime.

### Solution 1: Use Configuration Management

For incremental config changes without recreation:

```bash
# After initial Terraform provisioning
# Use Ansible for incremental updates

# Create Ansible playbook
cat > update-maria-config.yml <<EOF
---
- hosts: maria-primary
  tasks:
    - name: Update MariaDB config
      copy:
        src: maria-primary/config/my.cnf
        dest: /etc/mysql/mariadb.conf.d/99-custom.cnf
      notify: restart mariadb

  handlers:
    - name: restart mariadb
      service:
        name: mariadb
        state: restarted
EOF

# Run incremental update
ansible-playbook -i inventory update-maria-config.yml
```

### Solution 2: Manual Apply with Verification

```bash
# SSH to VM
ssh root@157.180.114.52

# Backup current config
cp /etc/mysql/mariadb.conf.d/99-custom.cnf /root/my.cnf.backup

# Test new config locally
mysql --help --verbose | grep max_connections

# Apply new config
vim /etc/mysql/mariadb.conf.d/99-custom.cnf

# Test syntax
mysqld --help --verbose &> /dev/null
echo $?  # 0 = OK

# Restart
systemctl restart mariadb

# Verify
systemctl status mariadb
```

**Then update source:**
```bash
# Update source to match
vim maria-primary/config/my.cnf
git commit -m "Update max_connections based on production test"
```

## Best Practices

### 1. Always Use Version Control

```bash
# Before any change
git add maria-primary/config/my.cnf
git commit -m "Working config: max_connections=500"

# Make change
# Test
# Commit if good, revert if bad
```

### 2. Test in Docker First

```
Change → Docker → Test → Works? → Apply to VM
                     ↓
                   Fails → Fix → Repeat
```

### 3. Keep Backups

```bash
# Before applying to VM
ssh root@157.180.114.52 "
  tar -czf /root/backup-$(date +%Y%m%d-%H%M%S).tar.gz \
    /etc/mysql \
    /var/lib/mysql
"
```

### 4. Document Changes

```bash
# In git commit messages
git commit -m "Increase max_connections from 500 to 1000

Reason: High connection load during peak hours
Tested: Docker environment, all tests pass
Risk: Low (backward compatible)
"
```

### 5. Gradual Rollout

```bash
# Test on one VM first
cd terraform/environments/vm
terraform apply -target=module.maria_primary

# Verify
./test-maria-primary.sh 157.180.114.52

# If good, apply to others
terraform apply
```

## Quick Reference

| Scenario | Command |
|----------|---------|
| Fix config file | Edit file → `terraform apply` |
| Fix provisioning script | Edit script → `terraform apply` |
| Force re-provision | `terraform taint module.maria_primary.null_resource.maria_primary` |
| Destroy and recreate | `terraform destroy -target=...` then `terraform apply` |
| Rollback with git | `git checkout HEAD -- <file>` then `terraform apply` |
| Test before VM | Apply to Docker first |

## Summary

✅ **You CAN fix and reapply configs easily:**
1. Edit source files locally
2. Terraform detects changes (checksums)
3. Run `terraform apply`
4. Re-provisions with fixed config

✅ **Terraform's triggers make it simple:**
- Change file → Hash changes → Auto re-provision
- No manual tracking needed
- Reproducible and safe

✅ **Best approach:**
- Fix source files (never edit VMs directly)
- Test in Docker first
- Use version control for rollback
- Apply to VMs with confidence

**The key:** Always edit source files, never the VMs directly!
