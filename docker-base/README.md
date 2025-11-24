# Base Docker Image for VM Simulation

This directory contains the base Docker image that simulates the real VMs used in production.

## Purpose

The `vm-base:debian12` image is designed to match the production VMs as closely as possible:
- **Same OS**: Debian 12 (Bookworm)
- **Same SSH setup**: Key-based authentication with `~/.ssh/redi_test_key`
- **Same packages**: Python3, openssh-server, sudo, vim, net-tools, etc.
- **Same users**: root user with SSH key, testuser with sudo access

## Building the Image

```bash
cd docker-base
./build.sh
```

The build script will:
1. Check that `~/.ssh/redi_test_key.pub` exists
2. Copy the SSH public key to the build context
3. Build the Docker image with the key baked in
4. Clean up temporary files

## What's Included

### Packages
- openssh-server - SSH daemon for remote access
- sudo - Superuser privileges
- vim - Text editor
- net-tools - Network utilities
- iputils-ping - Ping command
- curl, wget - HTTP clients
- ca-certificates - SSL certificates
- python3, python3-apt - Required for Ansible

### Users
- **root**: SSH access with key-based auth (no password)
- **testuser**: Regular user with sudo access (password: testpass)

### SSH Configuration
- Port 22 exposed
- Key-based authentication ONLY (PasswordAuthentication no)
- Root login allowed (with key)
- SSH key: `~/.ssh/redi_test_key.pub` pre-installed in `/root/.ssh/authorized_keys`

## Differences from VMs

The Docker containers have some minor differences from real VMs:
- **systemd**: Limited functionality in containers (some services may not start)
- **No persistent data**: Unless volumes are mounted
- **Network**: Uses Docker networking (bridge mode) instead of real network

## Matching VM Setup

The image is designed to match the production VM setup:

| Feature | Production VMs | Docker Containers |
|---------|---------------|-------------------|
| OS | Debian 12 | ✅ Debian 12 |
| SSH Key | ~/.ssh/redi_test_key | ✅ Same key |
| Password Auth | Disabled | ✅ Disabled |
| Python3 | Installed | ✅ Pre-installed |
| Base packages | Installed | ✅ Pre-installed |
| Root access | Via SSH key | ✅ Via SSH key |

## Updating the Image

If you change the SSH key or need to update packages:

```bash
cd docker-base
./build.sh
```

Then recreate all containers:

```bash
cd ..
./test-docker.sh clean
./test-docker.sh start
```

## Security Note

The SSH private key (`~/.ssh/redi_test_key`) is **never** copied into the image.
Only the public key (`~/.ssh/redi_test_key.pub`) is included, which is safe to distribute.

The image build process ensures:
- Private key never enters build context
- Public key is copied temporarily and removed after build
- `*.pub` files are in `.gitignore` (won't be committed)

## Troubleshooting

### "SSH public key not found"

The build script looks for `~/.ssh/redi_test_key.pub`. If it's missing:

```bash
# Check if the key exists
ls -l ~/.ssh/redi_test_key.pub

# If not, you need to generate it or get it from the actual VMs
```

### "Permission denied (publickey)"

If you get this error when connecting to containers:

```bash
# Verify you're using the correct key
ssh -i ~/.ssh/redi_test_key -p 2201 root@localhost

# Check the container has the key
docker exec maria-primary-test cat /root/.ssh/authorized_keys
```

### Rebuild Not Working

If changes aren't reflected:

```bash
# Force rebuild without cache
cd docker-base
docker build --no-cache -t vm-base:debian12 .
```

## Files

- `Dockerfile` - Image definition
- `build.sh` - Build script that handles SSH key
- `setup-ssh-key.sh` - (Deprecated) Old manual key injection script
- `README.md` - This file
