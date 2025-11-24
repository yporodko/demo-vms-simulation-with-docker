# Testing Ansible Playbooks with Docker

This guide explains how to test your Ansible playbooks locally using Docker containers before deploying to real VMs.

## Why Test with Docker First?

✅ **Safe** - Test on local containers, not production VMs
✅ **Fast** - No network latency, instant feedback
✅ **Free** - No cloud costs for testing
✅ **Reproducible** - Clean state every time
✅ **Isolated** - No risk of breaking real infrastructure

## Quick Start

### 1. Start Docker Containers

```bash
./test-docker.sh start
```

This will:
- Start maria-primary-test and maria-replica-test containers
- Wait for containers to be ready
- Clean SSH known_hosts (for fresh connections)
- Test connectivity (SSH keys are pre-configured in the image)

### 2. Deploy with Ansible

```bash
./test-docker.sh deploy
```

This runs the maria-primary playbook on the Docker container.

### 3. Verify Deployment

```bash
# SSH into the container
./test-docker.sh ssh maria-primary-test

# Inside the container, test MariaDB
mysql -u app_user -papp_password voip_db -e "SHOW TABLES;"
exit
```

### 4. Clean Up

```bash
./test-docker.sh stop   # Stop containers
./test-docker.sh clean  # Remove containers and volumes
```

## Available Commands

```bash
./test-docker.sh start    # Start containers and configure SSH
./test-docker.sh deploy   # Deploy maria-primary using Ansible
./test-docker.sh stop     # Stop containers
./test-docker.sh clean    # Remove containers and volumes
./test-docker.sh status   # Show container status
./test-docker.sh logs     # Show container logs
./test-docker.sh ssh      # SSH into container
./test-docker.sh rebuild  # Rebuild base Docker image
```

## Manual Testing

If you prefer to run commands manually:

```bash
# 1. Start containers
docker-compose up -d maria-primary-test

# 2. Wait for container to be ready
sleep 3

# 3. Clean SSH known_hosts (if needed)
ssh-keygen -R "[localhost]:2201"

# 4. Test Ansible connection (Python3 and SSH key are pre-configured in the image)
cd ansible
ansible -i inventory/hosts-docker-test.yml maria-primary-test -m ping

# 5. Run playbook
ansible-playbook -i inventory/hosts-docker-test.yml playbooks/maria-primary-test.yml
```

**Note**: SSH keys and Python3 are now pre-installed in the base Docker image (`vm-base:debian12`), matching the production VM setup. No manual key injection needed!

## Inventory Files

### Production VMs
`ansible/inventory/hosts.yml` - Points to real VMs with their IP addresses

### Docker Testing
`ansible/inventory/hosts-docker-test.yml` - Points to Docker containers on localhost with different SSH ports

## Docker Containers

All test containers use the same base image (`vm-base:debian12`) which matches production VMs:
- **Debian 12** (same as VMs)
- **SSH server** with key-based authentication ONLY (matches VMs)
- **SSH key** `~/.ssh/redi_test_key` pre-configured (matches VMs)
- **Python3 and python3-apt** pre-installed (required for Ansible)
- **Base packages**: vim, curl, wget, net-tools, iputils-ping, ca-certificates
- **testuser** with passwordless sudo access

**Key difference from old setup**: SSH keys are now **baked into the image** during build time, not injected at runtime. This exactly matches how production VMs are set up.

### Container Mapping

| Service | Container Name | SSH Port | Service Port |
|---------|---------------|----------|--------------|
| maria-primary | maria-primary-test | 2201 | 3306 |
| maria-replica | maria-replica-test | 2202 | 3307 |
| postgres-primary | postgres-primary-test | 2203 | 5432 |
| postgres-replica-1 | postgres-replica-1-test | 2204 | 5433 |
| postgres-replica-2 | postgres-replica-2-test | 2205 | 5434 |
| postgres-balancer | postgres-balancer-test | 2206 | 5435/5436/8404 |
| app-1 | app-1-test | 2207 | - |
| app-2 | app-2-test | 2208 | - |
| nginx | nginx-test | 2209 | 8000 |
| asterisk-1 | asterisk-1-test | 2210 | 5061 |
| asterisk-2 | asterisk-2-test | 2211 | 5062 |
| asterisk-balancer | asterisk-balancer-test | 2212 | 5060 |
| sipp | sipp-test | 2213 | - |

## Workflow: Docker → Production

### Step 1: Test on Docker

```bash
# Start containers
./test-docker.sh start

# Deploy and test
./test-docker.sh deploy

# Verify it works
./test-docker.sh ssh maria-primary-test
```

### Step 2: Deploy to Production

```bash
cd ansible

# Dry run on production
ansible-playbook playbooks/maria-primary.yml --check

# Deploy to production
ansible-playbook playbooks/maria-primary.yml
```

## Troubleshooting

### "Connection refused" error

```bash
# Check if containers are running
./test-docker.sh status

# Check SSH service in container
docker exec maria-primary-test service ssh status
```

### "Host key verification failed"

```bash
# Clean SSH known_hosts for the port
ssh-keygen -R "[localhost]:2201"
```

### "Python not found"

```bash
# Install Python in the container
docker exec maria-primary-test apt-get update -qq
docker exec maria-primary-test apt-get install -y python3 python3-apt
```

### Container keeps restarting

```bash
# Check container logs
./test-docker.sh logs maria-primary-test

# SSH might not be starting - restart it
docker exec maria-primary-test service ssh start
```

## Best Practices

1. **Always test on Docker first** before deploying to production VMs
2. **Use clean containers** - Run `./test-docker.sh clean` between major changes
3. **Test idempotency** - Run the playbook twice, second run should show `changed=0`
4. **Commit working playbooks** - Once Docker testing succeeds, commit to git
5. **Document changes** - Update role READMEs when you modify tasks

## Example Workflow

```bash
# 1. Make changes to Ansible role
vim ansible/roles/mariadb-primary/tasks/main.yml

# 2. Test on Docker
./test-docker.sh clean  # Start fresh
./test-docker.sh start
./test-docker.sh deploy

# 3. Verify
./test-docker.sh ssh maria-primary-test
# Run manual verification commands
exit

# 4. Test idempotency
cd ansible
ansible-playbook -i inventory/hosts-docker-test.yml playbooks/maria-primary-test.yml
# Should show changed=0 or minimal changes

# 5. Commit changes
git add ansible/roles/mariadb-primary/
git commit -m "Update mariadb-primary role"

# 6. Deploy to production
ansible-playbook playbooks/maria-primary.yml --check  # Dry run
ansible-playbook playbooks/maria-primary.yml          # Deploy
```

## Next Steps

After testing maria-primary successfully:

1. Create maria-replica role
2. Test maria-replica on Docker
3. Test replication between Docker containers
4. Deploy to production VMs
5. Repeat for PostgreSQL, Nginx, Asterisk roles

## Summary

Docker testing gives you:
- Safe environment to develop and test
- Fast feedback loop
- Confidence before production deployment
- Easy cleanup and fresh starts

Always follow the pattern: **Develop → Test on Docker → Deploy to Production**
