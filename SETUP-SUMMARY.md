# Infrastructure Test Setup - Summary

## What Has Been Created

A complete Docker-based infrastructure simulation replacing VMs with containers for all 4 test tasks.

## Quick Start

```bash
# Make scripts executable (if needed)
chmod +x quick-start.sh test-all.sh

# Start everything
./quick-start.sh

# Or manually:
docker-compose build
docker-compose up -d

# Run tests
./test-all.sh
```

## File Structure

```
redi-test/
├── docker-compose.yml          # Main orchestration file
├── hosts                       # Simulated hosts file
├── quick-start.sh             # Quick start script
├── test-all.sh                # Automated testing script
├── README.md                  # Complete documentation
├── ASTERISK-GUIDE.md          # Asterisk/SIP tutorial
│
├── maria-primary/             # Task 1: MariaDB Primary
│   ├── Dockerfile
│   ├── entrypoint.sh
│   ├── config/my.cnf
│   ├── init/voip_db.sql
│   └── data/                  # Persistent data (created on first run)
│
├── maria-replica/             # Task 1: MariaDB Replica
│   ├── Dockerfile
│   ├── entrypoint.sh
│   ├── config/my.cnf
│   └── data/
│
├── postgres-primary/          # Task 2: PostgreSQL Primary
│   ├── Dockerfile
│   ├── entrypoint.sh
│   ├── config/
│   │   ├── postgresql.conf
│   │   └── pg_hba.conf
│   └── data/
│
├── postgres-replica-1/        # Task 2: PostgreSQL Replica 1
│   ├── Dockerfile
│   ├── entrypoint.sh
│   ├── config/
│   └── data/
│
├── postgres-replica-2/        # Task 2: PostgreSQL Replica 2
│   ├── Dockerfile
│   ├── entrypoint.sh
│   ├── config/
│   └── data/
│
├── postgres-balancer/         # Task 2: HAProxy Load Balancer
│   ├── Dockerfile
│   ├── entrypoint.sh
│   └── config/haproxy.cfg
│
├── nginx/                     # Task 3: Nginx Reverse Proxy
│   ├── Dockerfile
│   ├── entrypoint.sh
│   ├── config/
│   │   ├── nginx.conf
│   │   └── default
│   └── logs/
│
├── app-1/                     # Task 3: App Server 1
│   ├── Dockerfile
│   └── entrypoint.sh
│
├── app-2/                     # Task 3: App Server 2
│   ├── Dockerfile
│   └── entrypoint.sh
│
├── asterisk-1/                # Task 4: Asterisk PBX 1
│   ├── Dockerfile
│   ├── entrypoint.sh
│   ├── config/
│   │   ├── asterisk.conf
│   │   ├── sip.conf
│   │   ├── extensions.conf
│   │   └── rtp.conf
│   └── data/
│
├── asterisk-2/                # Task 4: Asterisk PBX 2
│   ├── Dockerfile
│   ├── entrypoint.sh
│   ├── config/
│   └── data/
│
├── asterisk-balancer/         # Task 4: Kamailio Load Balancer
│   ├── Dockerfile
│   ├── entrypoint.sh
│   ├── config/
│   │   ├── kamailio.cfg
│   │   └── dispatcher.list
│   └── data/
│
└── sipp/                      # Task 4: SIP Testing Tool
    ├── Dockerfile
    ├── entrypoint.sh
    └── scenarios/
        └── basic_call.xml
```

## Services Overview

| Service | Container Name | IP Address | Ports (Host:Container) | Purpose |
|---------|---------------|------------|----------------------|---------|
| MariaDB Primary | maria-primary | 172.20.0.10 | 3306:3306, 2201:22 | Primary database |
| MariaDB Replica | maria-replica | 172.20.0.11 | 3307:3306, 2202:22 | Replica database |
| PostgreSQL Primary | postgres-primary | 172.20.0.20 | 5432:5432, 2203:22 | Primary database |
| PostgreSQL Replica 1 | postgres-replica-1 | 172.20.0.21 | 5433:5432, 2204:22 | Replica database |
| PostgreSQL Replica 2 | postgres-replica-2 | 172.20.0.22 | 5434:5432, 2205:22 | Replica database |
| PostgreSQL Balancer | postgres-balancer | 172.20.0.23 | 5435:5433, 5436:5432, 8404:8404, 2206:22 | Load balancer |
| App Server 1 | app-1 | 172.20.0.30 | 2207:22 | Backend app |
| App Server 2 | app-2 | 172.20.0.31 | 2208:22 | Backend app |
| Nginx | nginx | 172.20.0.32 | 8000:8000, 2209:22 | Reverse proxy |
| Asterisk 1 | asterisk-1 | 172.20.0.40 | 5061:5060, 2210:22 | VoIP PBX (80%) |
| Asterisk 2 | asterisk-2 | 172.20.0.41 | 5062:5060, 2211:22 | VoIP PBX (20%) |
| Asterisk Balancer | asterisk-balancer | 172.20.0.42 | 5060:5060, 2212:22 | SIP load balancer |
| SIPp | sipp | 172.20.0.50 | 2213:22 | Testing tool |

## Key Features

### Task 1: MariaDB Primary/Replica
- ✅ MariaDB 10.11 on both servers
- ✅ Primary/Replica replication configured
- ✅ Performance tuning (1GB buffer pool, query cache)
- ✅ Pre-configured with voip_db database
- ✅ Application user created

### Task 2: PostgreSQL Load Balancing
- ✅ PostgreSQL 9.6 on all servers
- ✅ Streaming replication configured
- ✅ HAProxy load balancer on port 5433
- ✅ Read queries distributed across replicas
- ✅ Write queries to primary
- ✅ HAProxy stats page (http://localhost:8404/stats)

### Task 3: Nginx Reverse Proxy
- ✅ Load balancing to app-1 and app-2
- ✅ DDoS protection (rate limiting, connection limits)
- ✅ Performance tuning (10,000 worker connections)
- ✅ Security headers configured
- ✅ Health check endpoint (/health)

### Task 4: Asterisk VoIP
- ✅ Two Asterisk PBX servers
- ✅ Kamailio load balancer (80/20 distribution)
- ✅ Dialplan configured:
  - Ring 10-20 seconds
  - 12% busy, 33% no answer, 55% answered
  - Play tt-monkeys for 15-45 seconds
- ✅ SIPp testing tool included

## SSH Access

All containers: `ssh -p <port> testuser@localhost`
Password: `testpass`

## Database Access

```bash
# MariaDB Primary
mysql -h localhost -P 3306 -u app_user -papp_password

# PostgreSQL Load Balanced Reads
psql -h localhost -p 5435 -U postgres -d ecommerce
```

## Web Access

```bash
# Nginx (load balanced to app servers)
curl http://localhost/

# HAProxy statistics
open http://localhost:8404/stats
```

## Asterisk Testing

```bash
# Enter SIPp container
docker exec -it sipp bash

# Make test calls
sipp -sn uac asterisk-balancer:5060 -m 10 -r 1
```

## Configuration Files

All services use configuration files from local directories:
- Mounted as read-only volumes
- Easy to edit and reload
- Persistent across container restarts

## Data Persistence

All databases store data in local directories:
- `maria-primary/data/`
- `maria-replica/data/`
- `postgres-primary/data/`
- `postgres-replica-1/data/`
- `postgres-replica-2/data/`
- `asterisk-1/data/`
- `asterisk-2/data/`

## Common Commands

```bash
# View logs
docker-compose logs -f [service-name]

# Restart a service
docker-compose restart [service-name]

# SSH into container
docker exec -it [container-name] bash

# Stop all services
docker-compose down

# Rebuild after changes
docker-compose build --no-cache [service-name]
docker-compose up -d
```

## Documentation

- **README.md** - Complete setup and testing guide
- **ASTERISK-GUIDE.md** - Detailed Asterisk/SIP tutorial for beginners
- **SETUP-SUMMARY.md** - This file, quick reference

## Network

All containers on `172.20.0.0/16` network:
- Can communicate using hostnames
- Fixed IP addresses for consistency
- Isolated from host network

## Testing Each Task

### Task 1: MariaDB
```bash
# Check replication
mysql -h localhost -P 3307 -u app_user -papp_password -e "SHOW SLAVE STATUS\G"

# Insert on primary, verify on replica
mysql -h localhost -P 3306 -u app_user -papp_password voip_db -e "INSERT INTO calls (caller_id, callee_id, call_status, codec_used, call_direction) VALUES ('1111', '2222', 'connected', 'G.711', 'outbound');"
mysql -h localhost -P 3307 -u app_user -papp_password voip_db -e "SELECT * FROM calls ORDER BY id DESC LIMIT 5;"
```

### Task 2: PostgreSQL
```bash
# Test load balancer
for i in {1..10}; do psql -h localhost -p 5435 -U postgres -d ecommerce -c "SELECT 'Query from replica', now();"; done

# Check HAProxy stats
curl http://localhost:8404/stats
```

### Task 3: Nginx
```bash
# Test load balancing
for i in {1..10}; do curl http://localhost/; echo "---"; done

# Monitor which server responds
docker-compose logs -f app-1 app-2
```

### Task 4: Asterisk
```bash
# Run 100 test calls
docker exec -it sipp sipp -sn uac asterisk-balancer:5060 -m 100 -r 5

# Monitor distribution
docker exec -it asterisk-1 asterisk -rx "core show channels"
docker exec -it asterisk-2 asterisk -rx "core show channels"
```

## Troubleshooting

1. **Containers not starting**: Check logs with `docker-compose logs [service]`
2. **Replication not working**: Wait 30 seconds after startup, replicas need time to sync
3. **Permission errors**: Check volume permissions in data directories
4. **Port conflicts**: Stop services using ports 8000, 3306, 5432, 5060, etc.

## What Makes This Different from Real VMs

✅ **Advantages**:
- Faster startup (seconds vs minutes)
- Less resource usage
- Easy to reset/rebuild
- Version controlled configuration
- Local development friendly

⚠️ **Limitations**:
- Shared kernel (not true isolation)
- No systemd by default (using service commands instead)
- Network is simulated (but functionally equivalent)

## Next Steps

1. Start the environment: `./quick-start.sh`
2. Run tests: `./test-all.sh`
3. Read task-specific guides in README.md
4. For Asterisk help, see ASTERISK-GUIDE.md
5. SSH into containers and explore
6. Modify configurations and rebuild

## Support

All configuration is pre-done and working. You can:
- SSH into any container
- Modify configs in local directories
- Restart services to apply changes
- View logs for troubleshooting

Enjoy testing! 🚀
