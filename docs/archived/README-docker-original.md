# Infrastructure Test Tasks - Docker Simulation

This repository contains a complete Docker-based simulation of the infrastructure test tasks, replacing VMs with Docker containers.

## Overview

All services are containerized with:
- Individual Dockerfiles per service
- Shared network (172.20.0.0/16)
- Persistent data volumes mapped to local directories
- SSH access to all containers (user: `testuser`, password: `testpass`)
- Configuration files mapped from local directories

## Architecture

### Task 1: MariaDB Primary/Replica
- **maria-primary** (172.20.0.10) - Primary MariaDB server
- **maria-replica** (172.20.0.11) - Replica MariaDB server
- Pre-configured with replication and voip_db database

### Task 2: PostgreSQL with Load Balancing
- **postgres-primary** (172.20.0.20) - Primary PostgreSQL 9.6 server
- **postgres-replica-1** (172.20.0.21) - First replica
- **postgres-replica-2** (172.20.0.22) - Second replica
- **postgres-balancer** (172.20.0.23) - HAProxy load balancer
  - Port 5432: Write queries (primary)
  - Port 5433: Read queries (load balanced across replicas)
  - Port 8404: HAProxy statistics page

### Task 3: Nginx Reverse Proxy
- **nginx** (172.20.0.32) - Reverse proxy with DDoS protection
- **app-1** (172.20.0.30) - Backend app server
- **app-2** (172.20.0.31) - Backend app server
- Load balancing with least_conn algorithm

### Task 4: Asterisk VoIP Load Balancing
- **asterisk-1** (172.20.0.40) - Asterisk PBX server (handles 80% of calls)
- **asterisk-2** (172.20.0.41) - Asterisk PBX server (handles 20% of calls)
- **asterisk-balancer** (172.20.0.42) - Kamailio SIP load balancer
- **sipp** (172.20.0.50) - SIPp testing tool

## Quick Start

### Prerequisites
- Docker
- Docker Compose

### Build and Start All Services

```bash
# Build all containers
docker-compose build

# Start all services
docker-compose up -d

# View logs
docker-compose logs -f

# Check status
docker-compose ps
```

### Stop All Services

```bash
docker-compose down
```

## Port Mappings

| Service | Internal Port | Host Port | Description |
|---------|--------------|-----------|-------------|
| maria-primary | 3306, 22 | 3306, 2201 | MariaDB, SSH |
| maria-replica | 3306, 22 | 3307, 2202 | MariaDB, SSH |
| postgres-primary | 5432, 22 | 5432, 2203 | PostgreSQL, SSH |
| postgres-replica-1 | 5432, 22 | 5433, 2204 | PostgreSQL, SSH |
| postgres-replica-2 | 5432, 22 | 5434, 2205 | PostgreSQL, SSH |
| postgres-balancer | 5433, 5432, 8404, 22 | 5435, 5436, 8404, 2206 | Load balancer, Stats, SSH |
| app-1 | 22 | 2207 | SSH |
| app-2 | 22 | 2208 | SSH |
| nginx | 80, 22 | 80, 2209 | HTTP, SSH |
| asterisk-1 | 5060, 22 | 5061, 2210 | SIP, SSH |
| asterisk-2 | 5060, 22 | 5062, 2211 | SIP, SSH |
| asterisk-balancer | 5060, 22 | 5060, 2212 | SIP, SSH |
| sipp | 22 | 2213 | SSH |

## SSH Access

All containers have SSH enabled:

```bash
# SSH to any container (example: maria-primary)
ssh -p 2201 testuser@localhost
# Password: testpass

# Or use docker exec
docker exec -it maria-primary bash
```

## Testing Instructions

### Task 1: MariaDB Primary/Replica

```bash
# Connect to primary
mysql -h localhost -P 3306 -u app_user -papp_password

# Check primary status
SHOW MASTER STATUS;

# Use the database
USE voip_db;
SELECT * FROM calls;

# Insert test data on primary
INSERT INTO calls (caller_id, callee_id, call_status, codec_used, call_direction, call_cost)
VALUES ('9999999999', '8888888888', 'connected', 'G.711', 'outbound', 0.15);

# Connect to replica and verify replication
mysql -h localhost -P 3307 -u app_user -papp_password

# Check replica status
SHOW SLAVE STATUS\G

# Verify data replicated
USE voip_db;
SELECT * FROM calls;
```

### Task 2: PostgreSQL Load Balancing

```bash
# Connect to primary for writes
psql -h localhost -p 5432 -U postgres -d ecommerce

# Check replication status
SELECT * FROM pg_stat_replication;

# Insert test data
INSERT INTO orders (customer_id, total_amount, status, shipping_address, payment_method)
VALUES (4, 199.99, 'pending', '321 Elm St, Portland, OR', 'credit_card');

# Connect to load balancer for reads (port 5433 -> distributed across replicas)
psql -h localhost -p 5435 -U postgres -d ecommerce

# Execute read queries (will be balanced)
SELECT * FROM orders;

# Check HAProxy stats
# Open in browser: http://localhost:8404/stats

# Test individual replicas
psql -h localhost -p 5433 -U postgres -d ecommerce  # replica-1
psql -h localhost -p 5434 -U postgres -d ecommerce  # replica-2
```

### Task 3: Nginx Reverse Proxy

```bash
# Test load balancing (should alternate between app-1 and app-2)
curl http://localhost/

# Run multiple requests to see load balancing
for i in {1..10}; do curl http://localhost/; echo "---"; done

# Test health check endpoint
curl http://localhost/health

# Load test with Apache Bench (if installed)
ab -n 1000 -c 10 http://localhost/

# Monitor Nginx logs
docker exec -it nginx tail -f /var/log/nginx/access.log
```

### Task 4: Asterisk Load Balancing

#### Understanding Asterisk Configuration

The Asterisk servers are configured to:
1. Ring for 10-20 seconds (random)
2. Respond with:
   - 12% BUSY
   - 33% NO ANSWER
   - 55% ANSWERED (plays tt-monkeys for 15-45 seconds)

#### Testing with SIPp

```bash
# SSH into SIPp container
docker exec -it sipp bash

# Simple test call to load balancer (80% -> asterisk-1, 20% -> asterisk-2)
sipp -sn uac asterisk-balancer:5060 -m 1 -r 1 -rp 1000

# Run 10 calls at 1 call/second
sipp -sn uac asterisk-balancer:5060 -m 10 -r 1 -d 60000

# Run 100 calls to test distribution (check logs to verify 80/20 split)
sipp -sn uac asterisk-balancer:5060 -m 100 -r 5

# Test direct connection to asterisk-1
sipp -sn uac asterisk-1:5060 -m 5 -r 1

# Test direct connection to asterisk-2
sipp -sn uac asterisk-2:5060 -m 5 -r 1
```

#### Monitor Asterisk

```bash
# Connect to Asterisk CLI on asterisk-1
docker exec -it asterisk-1 asterisk -rvvv

# Useful commands in Asterisk CLI:
core show channels
sip show peers
sip show channels
dialplan show

# View Asterisk logs
docker exec -it asterisk-1 tail -f /var/log/asterisk/messages

# Check Kamailio balancer
docker exec -it asterisk-balancer kamctl dispatcher dump
```

## Configuration Files

All configuration files are in their respective directories and mapped as volumes:

- `maria-primary/config/my.cnf` - MariaDB primary config
- `maria-replica/config/my.cnf` - MariaDB replica config
- `postgres-*/config/postgresql.conf` - PostgreSQL configs
- `postgres-balancer/config/haproxy.cfg` - HAProxy config
- `nginx/config/nginx.conf` - Nginx main config
- `nginx/config/default` - Nginx site config
- `asterisk-*/config/` - Asterisk configurations (sip.conf, extensions.conf)
- `asterisk-balancer/config/kamailio.cfg` - Kamailio config
- `asterisk-balancer/config/dispatcher.list` - Load balancer weights

## Data Persistence

All data is persisted in local directories:
- `maria-primary/data/` - MariaDB primary data
- `maria-replica/data/` - MariaDB replica data
- `postgres-*/data/` - PostgreSQL data directories
- `asterisk-*/data/` - Asterisk data
- `nginx/logs/` - Nginx access and error logs

## Troubleshooting

### Check container logs
```bash
docker-compose logs <service-name>
docker-compose logs -f maria-primary
```

### Restart a specific service
```bash
docker-compose restart <service-name>
```

### Rebuild after config changes
```bash
docker-compose down
docker-compose build --no-cache <service-name>
docker-compose up -d
```

### Clean up everything (WARNING: deletes data)
```bash
docker-compose down -v
rm -rf */data/*
```

### Check network connectivity
```bash
docker exec -it maria-primary ping postgres-primary
docker exec -it nginx ping app-1
```

## Understanding Asterisk Call Flow

1. **SIPp** sends INVITE to **asterisk-balancer:5060**
2. **Kamailio** distributes to asterisk-1 (80%) or asterisk-2 (20%)
3. **Asterisk** processes call:
   - Rings for 10-20 seconds
   - Randomly decides outcome (12% busy, 33% no answer, 55% answer)
   - If answered, plays tt-monkeys sound for 15-45 seconds
   - Hangs up

## Performance Tuning

### MariaDB
- Configured for high traffic with 1GB buffer pool
- Binary logging enabled for replication
- Connection limit: 500

### PostgreSQL
- Streaming replication with hot standby
- Configured with 256MB shared buffers

### Nginx
- Rate limiting enabled (10 req/s general, 5 req/s strict)
- Connection limits (10 per IP)
- Worker processes: auto
- Worker connections: 10000

### Asterisk
- RTP ports: 10000-20000
- Codecs: ulaw, alaw, gsm

## Network Information

All containers are on the same network: `172.20.0.0/16`

Containers can reach each other using hostnames:
- `maria-primary`, `maria-replica`
- `postgres-primary`, `postgres-replica-1`, `postgres-replica-2`
- `app-1`, `app-2`, `nginx`
- `asterisk-1`, `asterisk-2`, `asterisk-balancer`

## Additional Resources

- MariaDB Replication: https://mariadb.com/kb/en/replication/
- PostgreSQL Streaming Replication: https://www.postgresql.org/docs/9.6/warm-standby.html
- HAProxy Documentation: http://www.haproxy.org/
- Nginx Documentation: https://nginx.org/en/docs/
- Asterisk Documentation: https://wiki.asterisk.org/
- Kamailio Documentation: https://www.kamailio.org/docs/
- SIPp Documentation: http://sipp.sourceforge.net/doc/

## Security Note

This setup uses simple passwords and no encryption for testing purposes only.
For production use, implement:
- Strong passwords
- SSL/TLS encryption
- Firewall rules
- Proper authentication mechanisms
