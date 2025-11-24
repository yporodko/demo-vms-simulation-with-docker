# Terraform State Drift and Manual Changes

## The Problem

**Question:** If someone manually edits a VM (SSH in and changes configs), can Terraform detect what was changed?

**Answer:** **No, not with our current setup.**

## Why Not?

### How Terraform Tracks State

Terraform has two types of resources:

#### 1. **Managed Resources** (Terraform CAN detect drift)

Examples: AWS EC2, Google Cloud VMs, Docker containers (via provider)

```hcl
# Terraform creates and manages the VM
resource "aws_instance" "web" {
  ami           = "ami-123456"
  instance_type = "t2.micro"
}
```

**What Terraform can do:**
- Query the cloud API
- Check actual state vs. desired state
- Detect drift: "Hey, someone changed the instance type!"

#### 2. **Null Resources with Provisioners** (Terraform CANNOT detect drift)

This is what we use:

```hcl
# Terraform just runs scripts via SSH
resource "null_resource" "maria_primary" {
  provisioner "remote-exec" {
    inline = ["/tmp/install-mariadb.sh"]
  }
}
```

**What Terraform tracks:**
- ✅ Did I run this provisioner? (yes/no)
- ✅ What were the script checksums?
- ❌ What's actually installed on the VM now?
- ❌ Has anyone changed the config files?
- ❌ Is MariaDB still running?

### Our Current Setup

```
Terraform State File:
{
  "null_resource.maria_primary": {
    "id": "12345",
    "triggers": {
      "install_script_hash": "abc123"
    }
  }
}
```

**This ONLY tracks:**
- Resource was created
- Scripts had these checksums when run

**It does NOT track:**
- MariaDB version on the VM
- Configuration files on the VM
- Whether MariaDB is running
- What packages are installed

## Real-World Scenarios

### Scenario 1: Someone Manually Edits MariaDB Config

```bash
# Someone SSHs to the VM
ssh root@157.180.114.52

# Manually edits config
vim /etc/mysql/mariadb.conf.d/99-custom.cnf
# Changes max_connections from 500 to 1000

# Restarts MariaDB
systemctl restart mariadb
```

**What happens when you run `terraform plan`?**

```bash
cd terraform/environments/vm
terraform plan
```

**Output:**
```
No changes. Your infrastructure matches the configuration.
```

**Why?** Terraform doesn't know about the manual change. It only knows:
- "I ran the provisioning scripts before"
- "Script checksums haven't changed"
- "Nothing to do"

### Scenario 2: Someone Manually Uninstalls MariaDB

```bash
# Someone SSHs to the VM
ssh root@157.180.114.52

# Uninstalls MariaDB completely
apt-get purge -y mariadb-server mariadb-client
rm -rf /var/lib/mysql
```

**What happens when you run `terraform plan`?**

```bash
terraform plan
```

**Output:**
```
No changes. Your infrastructure matches the configuration.
```

**Why?** Terraform still thinks everything is fine because:
- The `null_resource` still exists in state
- Script checksums haven't changed

### Scenario 3: You Change a Provisioning Script

```bash
# You edit the install script
vim provisioning/maria-primary/install.sh
# Add a new package

terraform plan
```

**Output:**
```
Plan: 1 to add, 0 to change, 1 to destroy.

null_resource.maria_primary must be replaced
  ~ triggers = {
      ~ install_script_hash = "old_hash" → "new_hash"
    }
```

**Why?** The trigger detected the change!

**What happens on `terraform apply`?**
- Destroys the old `null_resource`
- Creates a new one
- Re-runs ALL provisioning scripts
- **Overwrites any manual changes**

## Solutions and Workarounds

### Option 1: Accept the Limitation

**Strategy:** Use Terraform for initial provisioning only

```bash
# First time: Provision with Terraform
terraform apply

# After that: Manage manually or with Ansible/Chef/Puppet
```

**Pros:**
- Simple
- Terraform does what it's good at (initial setup)
- Use better tools for configuration management

**Cons:**
- Drift can happen
- No automated drift detection

### Option 2: Force Re-provisioning

**Strategy:** Manually trigger re-provisioning when needed

```bash
# Taint the resource (mark for recreation)
terraform taint module.maria_primary.null_resource.maria_primary

# Re-provision
terraform apply
```

**What happens:**
- Re-runs all provisioning scripts
- Overwrites manual changes
- Returns VM to known state

### Option 3: Use Triggers to Force Updates

**Strategy:** Add a timestamp or version trigger

```hcl
resource "null_resource" "maria_primary" {
  triggers = {
    install_script_hash = filemd5("install.sh")
    config_hash         = filemd5("my.cnf")
    force_update        = timestamp()  # Always changes!
  }
}
```

**Pros:** Always re-provisions
**Cons:** Re-provisions EVERY time (probably not what you want)

**Better approach:**
```hcl
triggers = {
  install_script_hash = filemd5("install.sh")
  config_hash         = filemd5("my.cnf")
  version             = "1.0"  # Increment manually to force update
}
```

### Option 4: Combine with Configuration Management

**Strategy:** Use Terraform for infrastructure, Ansible for config

```bash
# Terraform: Provision base system
terraform apply

# Ansible: Configure and maintain services
ansible-playbook -i inventory maria-primary.yml
```

**Pros:**
- Terraform does initial setup
- Ansible detects and fixes drift
- Best tool for each job

**Cons:**
- More complexity
- Two tools to learn

### Option 5: Build Immutable Infrastructure

**Strategy:** Never update, always replace

```bash
# Don't edit VMs
# Instead: Change config → Rebuild VM → Replace old VM
```

**Flow:**
1. Change config file
2. Terraform detects hash change
3. Destroys old VM and creates new one
4. New VM has correct config

**Pros:**
- No drift (VMs are ephemeral)
- Always in known state

**Cons:**
- Requires automation for VM lifecycle
- Not suitable for VMs with persistent data

## Detecting Drift Manually

Since Terraform can't detect it automatically, you can:

### 1. SSH and Check Manually

```bash
# SSH to VM
ssh root@157.180.114.52

# Check MariaDB version
mysql --version

# Check config
cat /etc/mysql/mariadb.conf.d/99-custom.cnf

# Compare with source
diff /etc/mysql/mariadb.conf.d/99-custom.cnf \
     /path/to/your/maria-primary/config/my.cnf
```

### 2. Write a Verification Script

```bash
#!/bin/bash
# verify-maria-primary.sh

echo "Checking MariaDB on $1..."

ssh root@$1 "
  # Check if MariaDB is installed
  if ! command -v mysql &> /dev/null; then
    echo 'ERROR: MariaDB not installed'
    exit 1
  fi

  # Check if running
  if ! systemctl is-active mariadb; then
    echo 'ERROR: MariaDB not running'
    exit 1
  fi

  # Check config
  if ! grep -q 'max_connections = 500' /etc/mysql/mariadb.conf.d/99-custom.cnf; then
    echo 'WARNING: Config may have been modified'
  fi

  echo 'OK: MariaDB looks good'
"
```

**Usage:**
```bash
./verify-maria-primary.sh 157.180.114.52
```

### 3. Use Terraform's `local-exec` for Verification

Add to your Terraform module:

```hcl
resource "null_resource" "verify_maria_primary" {
  depends_on = [null_resource.maria_primary]

  provisioner "local-exec" {
    command = "./verify-maria-primary.sh ${var.target_host}"
  }
}
```

## Best Practices for Our Setup

### 1. **Document the State**

After provisioning, document what was done:

```bash
# After terraform apply
ssh root@157.180.114.52 "
  mysql --version > /root/provisioned-state.txt
  dpkg -l | grep maria >> /root/provisioned-state.txt
  cat /etc/mysql/mariadb.conf.d/99-custom.cnf >> /root/provisioned-state.txt
"
```

### 2. **Use Version Control**

Keep all configs in Git:
- Provisioning scripts
- Config files
- Terraform code

Manual changes should go through Git.

### 3. **Establish Change Process**

```
Manual change needed?
  ↓
1. Update source files (provisioning scripts or configs)
  ↓
2. Commit to Git
  ↓
3. Run terraform apply (triggers detect change)
  ↓
4. Re-provisions automatically
```

### 4. **Regular Re-provisioning**

Periodically destroy and recreate to eliminate drift:

```bash
# Every week/month
terraform destroy -target=module.maria_primary
terraform apply
```

### 5. **Testing Environment**

Always test in Docker first:

```bash
# Test changes in Docker
cd terraform/environments/docker
terraform apply

# Verify everything works
./test-maria-primary.sh

# Then apply to VMs
cd ../vm
terraform apply
```

## Summary

| Question | Answer |
|----------|--------|
| Can Terraform detect manual VM changes? | **No** (with null_resource) |
| Can Terraform detect script changes? | **Yes** (via triggers) |
| Will manual changes be overwritten? | **Yes** (when re-provisioning) |
| Can I force re-provisioning? | **Yes** (`terraform taint` or change trigger) |
| Should I make manual changes? | **No** (update source files instead) |

## Recommended Workflow

```
Need to change MariaDB config?
  ↓
❌ DON'T: SSH to VM and edit /etc/mysql/my.cnf
  ↓
✅ DO:
  1. Edit maria-primary/config/my.cnf locally
  2. Commit to Git
  3. Run terraform apply
  4. Terraform detects hash change
  5. Re-provisions with new config
```

**This ensures:**
- Changes are tracked
- Reproducible
- No drift
- Infrastructure as Code principles maintained
