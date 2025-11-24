# Archived Docker Compose Files

This directory contains old docker-compose files from previous approaches that are no longer in use.

## Files

### docker-compose.yml (Original)
- **Date**: Created before switching to Ansible
- **Purpose**: Used individual Dockerfiles for each service (maria-primary, maria-replica, etc.)
- **Approach**: Built separate images with MariaDB/PostgreSQL pre-installed
- **Why archived**: We switched to using Ansible for configuration management instead of pre-built images

### docker-compose.base.yml
- **Date**: Created during Terraform exploration
- **Purpose**: Base containers for Terraform provisioning
- **Approach**: Used `vm-base:debian12` image with Terraform for configuration
- **Why archived**: We switched from Terraform to Ansible

## Current Approach

We now use:
- **`docker-compose.yml`** (at project root) - Single compose file with base images
- **Ansible** for all configuration management
- **`vm-base:debian12`** base image that matches production VMs

## Why We Changed

### Old Approach Issues:
- ❌ Separate Dockerfiles for each service (lots of duplication)
- ❌ Configuration baked into images (not flexible)
- ❌ Didn't match how production VMs work
- ❌ Testing didn't reflect real deployment process

### New Approach Benefits:
- ✅ Single base image matches production VMs
- ✅ Ansible configures containers exactly like production
- ✅ Test environment mirrors production deployment
- ✅ Configuration as code (Ansible roles)
- ✅ Idempotent and reusable

## Historical Context

Evolution of our Docker testing approach:

1. **Phase 1**: Individual Dockerfiles with services pre-installed
2. **Phase 2**: Terraform with base images (explored but not fully implemented)
3. **Phase 3**: Ansible with base images (current - best matches production)

These files are kept for reference but should not be used.
