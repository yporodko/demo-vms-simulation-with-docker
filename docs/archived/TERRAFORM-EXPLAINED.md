# How Terraform Knows What to Apply

## Quick Answer

Terraform knows what to apply based on:
1. **Where you run it** (which directory)
2. **What's in the `.tf` files** (configuration)
3. **What's in the state file** (what it has already done)

## Visual Explanation

```
Your Project Structure:
└── terraform/
    ├── modules/
    │   └── maria-primary/          # RECIPE: How to provision maria-primary
    │       └── main.tf
    │
    └── environments/
        ├── docker/                 # DOCKER TARGET
        │   ├── main.tf            ← YOU ARE HERE when you run terraform
        │   └── terraform.tfstate  ← Terraform tracks what it did
        │
        └── vm/                     # VM TARGET
            ├── main.tf            ← Different target configuration
            └── terraform.tfstate  ← Separate state
```

## Example: Running Terraform in Docker Environment

### Step 1: You Navigate to a Directory

```bash
cd terraform/environments/docker
```

**This tells Terraform:** "I want to work with the Docker environment"

### Step 2: You Run Terraform

```bash
terraform apply
```

**Terraform does this:**

```
┌─────────────────────────────────────────────────────────┐
│ 1. Read main.tf in current directory                    │
│    → Found: module "maria_primary" { ... }              │
│    → Target: localhost:2201                             │
│                                                          │
│ 2. Load the module from modules/maria-primary/          │
│    → Recipe: Install MariaDB via SSH                    │
│                                                          │
│ 3. Check terraform.tfstate                              │
│    → Has this been done before?                         │
│    → No state file = First time                         │
│                                                          │
│ 4. Connect via SSH                                      │
│    → SSH to localhost:2201                              │
│    → Upload scripts                                     │
│    → Execute provisioning                               │
│                                                          │
│ 5. Save to terraform.tfstate                            │
│    → Record what was done                               │
│    → Save triggers/checksums                            │
└─────────────────────────────────────────────────────────┘
```

## What's in Each File

### `environments/docker/main.tf` (WHAT to provision)

```hcl
# This file says: "Provision maria-primary on localhost:2201"

module "maria_primary" {
  source = "../../modules/maria-primary"  # Use this recipe

  # Parameters for THIS environment
  target_host     = "localhost"           # Docker container
  ssh_port        = 2201                  # Docker SSH port
  ssh_private_key = "~/.ssh/redi_test_key"
}
```

### `modules/maria-primary/main.tf` (HOW to provision)

```hcl
# This file says: "HOW to provision maria-primary (any target)"

resource "null_resource" "maria_primary" {
  connection {
    host = var.target_host  # Will be "localhost" for Docker
    port = var.ssh_port     # Will be 2201 for Docker
  }

  # Upload scripts
  provisioner "file" {
    source = "provisioning/maria-primary/install.sh"
    destination = "/tmp/maria-install.sh"
  }

  # Run scripts
  provisioner "remote-exec" {
    inline = ["/tmp/maria-install.sh"]
  }
}
```

## Same Module, Different Targets

### Docker Environment

```bash
cd terraform/environments/docker
terraform apply
```

**Provisions to:**
- Host: `localhost`
- Port: `2201` (Docker container)
- Auth: SSH key

### VM Environment

```bash
cd terraform/environments/vm
terraform apply
```

**Provisions to:**
- Host: `157.180.114.52` (from VM hosts.txt)
- Port: `22` (real VM)
- Auth: SSH key

**Same provisioning scripts, different targets!**

## The State File

After running `terraform apply`, a state file is created:

```bash
terraform/environments/docker/terraform.tfstate
```

**Contents (simplified):**
```json
{
  "resources": [
    {
      "type": "null_resource",
      "name": "maria_primary",
      "instances": [{
        "attributes": {
          "id": "8234234234234",
          "triggers": {
            "maria_install_hash": "e711fe2a33cf193c4608e44c52add8c5"
          }
        }
      }]
    }
  ]
}
```

**What this means:**
- Terraform has created a resource
- It has this ID
- It used scripts with these checksums
- If scripts change, triggers change → re-provision

## How Terraform Decides to Re-run

### Triggers in the Module

```hcl
resource "null_resource" "maria_primary" {
  triggers = {
    maria_install_hash = filemd5("provisioning/maria-primary/install.sh")
    maria_config_hash  = filemd5("provisioning/maria-primary/configure.sh")
    my_cnf_hash        = filemd5("maria-primary/config/my.cnf")
  }
}
```

**What happens:**

| Scenario | Terraform Action |
|----------|------------------|
| First run (no state file) | Create resource → Run provisioning |
| Re-run, no changes | Do nothing (state matches config) |
| Script changed | Detect hash change → Destroy & recreate → Re-provision |
| Config file changed | Detect hash change → Destroy & recreate → Re-provision |

## Practical Example

### First Time

```bash
cd terraform/environments/docker
terraform apply
```

**Output:**
```
Plan: 1 to add, 0 to change, 0 to destroy.

module.maria_primary.null_resource.maria_primary will be created
  + triggers = {
      + maria_install_hash = "e711fe2a..."
    }
```

**Result:** MariaDB gets installed on localhost:2201

### Second Time (no changes)

```bash
terraform apply
```

**Output:**
```
No changes. Your infrastructure matches the configuration.
```

**Result:** Nothing happens (already provisioned)

### After Changing a Script

```bash
# Edit provisioning script
vim ../../../provisioning/maria-primary/install.sh

terraform apply
```

**Output:**
```
Plan: 1 to add, 0 to change, 1 to destroy.

module.maria_primary.null_resource.maria_primary must be replaced
  ~ triggers = {
      ~ maria_install_hash = "e711fe2a..." → "NEW_HASH..."
    }
```

**Result:** Re-provisions with new script

## Multiple Services

If you add more services to `environments/docker/main.tf`:

```hcl
module "maria_primary" {
  source      = "../../modules/maria-primary"
  target_host = "localhost"
  ssh_port    = 2201
}

module "maria_replica" {
  source      = "../../modules/maria-replica"
  target_host = "localhost"
  ssh_port    = 2202  # Different port!
}

module "postgres_primary" {
  source      = "../../modules/postgres-primary"
  target_host = "localhost"
  ssh_port    = 2203  # Different port!
}
```

**When you run `terraform apply`:**
- Provisions ALL services defined in this file
- Each to its respective target (port 2201, 2202, 2203)
- Tracks all in the same state file

## Directory = Environment

```
terraform/environments/docker/
  → Provisions to Docker containers (localhost)
  → State: terraform.tfstate (Docker environment)

terraform/environments/vm/
  → Provisions to real VMs (from VM hosts.txt)
  → State: terraform.tfstate (VM environment)
```

**They are independent!**
- Running `apply` in `docker/` only affects Docker containers
- Running `apply` in `vm/` only affects real VMs
- Separate state files track each environment

## Summary

**Terraform knows what to apply based on:**

1. **Current Directory**
   - `environments/docker/` → Docker targets
   - `environments/vm/` → VM targets

2. **main.tf in That Directory**
   - Which modules to use
   - What parameters to pass
   - What hosts/ports to target

3. **Modules**
   - The actual provisioning logic
   - Scripts to upload and run
   - Configuration files to copy

4. **State File**
   - What has been done before
   - Current resource checksums
   - Whether to re-provision

**Flow:**
```
You run: terraform apply
         ↓
Where:   terraform/environments/docker/
         ↓
Reads:   main.tf → module maria_primary
         ↓
Uses:    modules/maria-primary/main.tf
         ↓
Target:  localhost:2201 (from variables)
         ↓
Action:  SSH + upload scripts + execute
         ↓
Saves:   terraform.tfstate
```

**To provision to different targets, just change the directory!**

```bash
# Provision to Docker
cd terraform/environments/docker && terraform apply

# Provision to VMs
cd terraform/environments/vm && terraform apply
```
