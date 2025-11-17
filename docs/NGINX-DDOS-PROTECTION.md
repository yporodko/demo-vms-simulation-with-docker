# Nginx DDoS Protection Guide

## 🛡️ DDoS Protection Layers

### 1. **Rate Limiting** (Primary Defense)

**Configuration** (`nginx.conf:35-36`):
```nginx
limit_req_zone $binary_remote_addr zone=general:10m rate=10r/s;
limit_req_zone $binary_remote_addr zone=strict:10m rate=5r/s;
```

**Applied in site** (`default:6`):
```nginx
limit_req zone=general burst=20 nodelay;
```

**How it works:**
- Tracks each IP address (`$binary_remote_addr` - uses less memory than text IP)
- **Zone "general"**: 10MB memory, limits to **10 requests/second per IP**
- **Burst**: Allows temporary spike of **20 requests** above limit
- **nodelay**: Rejects excess requests immediately (no queueing)

**Effect**: An attacker from a single IP can only make:
- Sustained: 10 requests/second
- Burst: 30 requests in first second (10 normal + 20 burst), then 10/sec
- Excess requests get **503 Service Unavailable**

### 2. **Connection Limiting** (Prevents Connection Exhaustion)

**Configuration** (`nginx.conf:37,40`):
```nginx
limit_conn_zone $binary_remote_addr zone=addr:10m;
limit_conn addr 10;
```

**How it works:**
- Limits each IP to **10 simultaneous connections**
- Uses 10MB to track connections

**Effect**:
- Prevents slowloris attacks (slow connections that tie up server resources)
- Single IP cannot open more than 10 concurrent connections
- Attacker cannot exhaust connection pool

### 3. **Aggressive Timeouts** (Kills Slow Attacks)

**Configuration** (`default:15-17`):
```nginx
client_body_timeout 10s;
client_header_timeout 10s;
client_max_body_size 10m;
```

**How it works:**
- **10 second timeout** for client to send headers
- **10 second timeout** for client to send body
- **10MB max** request size

**Effect**:
- Kills slow HTTP attacks (Slowloris, Slow POST)
- Prevents large payload attacks
- Frees up connections quickly

### 4. **Backend Protection via Proxy Timeouts** (`default:31-33`)

```nginx
proxy_connect_timeout 5s;
proxy_send_timeout 10s;
proxy_read_timeout 10s;
```

**How it works:**
- 5 seconds to connect to backend
- 10 seconds for backend to respond

**Effect**:
- Nginx won't wait forever for slow backends
- Protects backend from being overwhelmed
- Fails fast and returns error to client

### 5. **Performance Optimizations** (Handles Legitimate Load)

**Worker Configuration** (`nginx.conf:2,7-9`):
```nginx
worker_processes auto;
worker_connections 10000;
use epoll;
multi_accept on;
```

**How it works:**
- **auto**: Spawns 1 worker per CPU core
- **10,000 connections per worker**: Can handle massive concurrent load
- **epoll**: Efficient event handling (Linux-specific)
- **multi_accept**: Accept multiple connections at once

**Effect**:
- Can handle 10,000+ legitimate simultaneous connections
- High throughput for valid traffic
- Doesn't fall over under normal load spikes

### 6. **Backend Health Checks** (`nginx.conf:45-46`)

```nginx
max_fails=3 fail_timeout=30s;
```

**How it works:**
- If backend fails 3 times, mark it down for 30 seconds
- Automatically removes unhealthy backends from rotation

**Effect**:
- Prevents cascading failures during attack
- Keeps serving from healthy backends

### 7. **Security Headers** (`default:10-12`)

```nginx
add_header X-Frame-Options "SAMEORIGIN" always;
add_header X-Content-Type-Options "nosniff" always;
add_header X-XSS-Protection "1; mode=block" always;
```

**How it works:**
- Not DDoS-specific, but prevents exploitation
- Reduces attack surface

### 8. **Information Hiding** (`nginx.conf:19`)

```nginx
server_tokens off;
```

**How it works:**
- Hides Nginx version from responses
- Attackers can't target version-specific exploits

## 📊 Attack Scenarios & Protection

### Scenario 1: HTTP Flood Attack
**Attack**: 1000 req/sec from single IP
- ✅ **Blocked**: Rate limit allows only 10/sec + 20 burst
- Result: 970 requests/sec rejected with 503

### Scenario 2: Distributed Attack (100 IPs × 15 req/sec)
**Attack**: 1500 total req/sec from 100 IPs
- ⚠️ **Partially Mitigated**: Each IP gets 10/sec
- Result: Max 1000 req/sec pass through (100 IPs × 10/sec)
- Backend still protected, but need layer 7 firewall for better protection

### Scenario 3: Slowloris (Slow Connection Attack)
**Attack**: Open many connections, send data very slowly
- ✅ **Blocked**:
  - Max 10 connections per IP
  - 10s header timeout kills slow requests
  - Connection limit prevents exhaustion

### Scenario 4: Large POST Attack
**Attack**: Send huge POST bodies
- ✅ **Blocked**: 10MB limit + 10s timeout
- Result: Large requests rejected

### Scenario 5: Backend Targeting
**Attack**: Try to overwhelm backend servers
- ✅ **Protected**:
  - Nginx buffers requests
  - Keepalive to backend reduces overhead
  - Backend marked down if failing
  - Load balanced across 2 servers

## 🔧 Testing the Protection

You can test these limits:

```bash
# Test rate limiting (will see 503 errors after limit)
ab -n 100 -c 50 http://localhost/

# Test connection limit (some connections will be rejected)
for i in {1..20}; do curl http://localhost/ & done

# Test timeout (should timeout after 10s)
telnet localhost 8000
# Don't send anything, wait 15 seconds

# Monitor rejected requests in logs
docker exec -it nginx tail -f /var/log/nginx/error.log | grep "limiting"
```

## 📈 Real-World Testing Examples

### Test 1: Rate Limit Verification

```bash
# Install Apache Bench if needed
# apt-get install apache2-utils

# Send 100 requests with 10 concurrent connections
ab -n 100 -c 10 http://localhost/

# Expected output:
# - Some requests will succeed
# - Some will get 503 (Service Unavailable)
# - Check "Non-2xx responses" in results
```

### Test 2: Connection Limit Test

```bash
# Open 15 simultaneous connections (exceeds limit of 10)
for i in {1..15}; do
  (curl -s http://localhost/ && echo "Success $i") &
done
wait

# Expected: Some connections rejected or delayed
```

### Test 3: Monitor Rate Limiting in Real-Time

```bash
# Terminal 1: Watch error log
docker exec -it nginx tail -f /var/log/nginx/error.log

# Terminal 2: Generate load
while true; do curl -s http://localhost/ > /dev/null; done

# You'll see messages like:
# "limiting requests, excess: 20.123 by zone "general""
```

### Test 4: Slowloris Simulation

```bash
# Manual slow request test
(
  exec 3<>/dev/tcp/localhost/80
  echo -e "GET / HTTP/1.1\r" >&3
  echo -e "Host: localhost\r" >&3
  # Don't send final blank line, wait for timeout
  sleep 15
  cat <&3
)

# Expected: Connection closed after ~10 seconds
```

## 📋 Configuration Reference

### Current Limits

| Protection Type | Limit | Configuration |
|----------------|-------|---------------|
| Requests per second (per IP) | 10 r/s | `limit_req_zone` rate |
| Burst requests | 20 | `limit_req` burst |
| Concurrent connections (per IP) | 10 | `limit_conn addr` |
| Request header timeout | 10s | `client_header_timeout` |
| Request body timeout | 10s | `client_body_timeout` |
| Max request size | 10MB | `client_max_body_size` |
| Backend connect timeout | 5s | `proxy_connect_timeout` |
| Backend response timeout | 10s | `proxy_read_timeout` |
| Worker connections | 10,000 | `worker_connections` |

### Tuning Recommendations

**For Higher Traffic (Legitimate)**:
```nginx
# Increase rate limits
limit_req_zone $binary_remote_addr zone=general:10m rate=50r/s;
limit_req zone=general burst=100 nodelay;

# Increase connection limit
limit_conn addr 50;
```

**For Stricter Protection**:
```nginx
# Decrease rate limits
limit_req_zone $binary_remote_addr zone=general:10m rate=5r/s;
limit_req zone=general burst=10 nodelay;

# Decrease connection limit
limit_conn addr 5;

# Shorter timeouts
client_body_timeout 5s;
client_header_timeout 5s;
```

**For API Endpoints** (different limits per path):
```nginx
location /api/ {
    limit_req zone=strict burst=5 nodelay;  # Stricter
    limit_conn addr 5;
}

location /static/ {
    limit_req zone=general burst=50 nodelay;  # More lenient
}
```

## 🚨 Monitoring DDoS Attacks

### Check Attack Indicators

```bash
# Count rate limit rejections
docker exec nginx grep "limiting requests" /var/log/nginx/error.log | wc -l

# Show top attacking IPs
docker exec nginx awk '{print $1}' /var/log/nginx/access.log | sort | uniq -c | sort -nr | head -10

# Count HTTP status codes
docker exec nginx awk '{print $9}' /var/log/nginx/access.log | sort | uniq -c | sort -nr

# Real-time request rate
docker exec nginx tail -f /var/log/nginx/access.log | pv -l -i 1 > /dev/null
```

### Signs of DDoS Attack

Look for:
- High number of 503 errors (rate limiting triggered)
- Many requests from same IPs
- Unusual traffic patterns in logs
- High CPU/memory usage on nginx container

```bash
# Monitor resources
docker stats nginx

# Watch request patterns
docker exec nginx tail -f /var/log/nginx/access.log | awk '{print $1}' | uniq -c
```

## 📈 Improvements You Could Add

For even stronger DDoS protection, you could add:

### 1. GeoIP Blocking
```nginx
# Block specific countries
http {
    geoip_country /usr/share/GeoIP/GeoIP.dat;

    map $geoip_country_code $allowed_country {
        default yes;
        CN no;  # Block China
        RU no;  # Block Russia
    }
}

server {
    if ($allowed_country = no) {
        return 403;
    }
}
```

### 2. fail2ban Integration
```bash
# Install fail2ban
apt-get install fail2ban

# Create nginx-limit-req jail
# /etc/fail2ban/filter.d/nginx-limit-req.conf
[Definition]
failregex = limiting requests, excess:.* by zone.*client: <HOST>

# Ban for 1 hour after 5 violations
[nginx-limit-req]
enabled = true
filter = nginx-limit-req
logpath = /var/log/nginx/error.log
maxretry = 5
bantime = 3600
```

### 3. ModSecurity WAF
```nginx
# Add web application firewall
load_module modules/ngx_http_modsecurity_module.so;

http {
    modsecurity on;
    modsecurity_rules_file /etc/nginx/modsec/main.conf;
}
```

### 4. Request Challenge
```nginx
# Require cookie from JavaScript challenge
location / {
    if ($cookie_challenge != "passed") {
        return 307 /challenge.html;
    }
    proxy_pass http://app_backend;
}
```

### 5. IP Whitelisting
```nginx
# Only allow specific IPs
geo $whitelist {
    default 0;
    10.0.0.0/8 1;       # Internal network
    203.0.113.0/24 1;   # Office IP range
}

server {
    if ($whitelist = 0) {
        return 403;
    }
}
```

### 6. Advanced Rate Limiting by URI
```nginx
# Different limits per endpoint
map $request_uri $limit_key {
    ~*/api/heavy-operation  $binary_remote_addr;
    default                  "";
}

limit_req_zone $limit_key zone=api_heavy:10m rate=1r/s;

location /api/heavy-operation {
    limit_req zone=api_heavy burst=2 nodelay;
}
```

## 📚 Additional Resources

- [Nginx Rate Limiting Guide](https://www.nginx.com/blog/rate-limiting-nginx/)
- [DDoS Protection with Nginx](https://www.nginx.com/blog/mitigating-ddos-attacks-with-nginx-and-nginx-plus/)
- [Nginx Security Best Practices](https://nginx.org/en/docs/http/ngx_http_limit_req_module.html)

## Summary

The current Nginx setup protects against:
- ✅ Single-source floods (rate limiting)
- ✅ Connection exhaustion (connection limits)
- ✅ Slow attacks (aggressive timeouts)
- ✅ Large payloads (size limits)
- ✅ Backend overload (health checks, load balancing)
- ⚠️ Distributed attacks (partially - limits per-IP, need additional layers)

This configuration is **production-ready** for moderate DDoS protection and handles most common attack vectors effectively!

## Quick Reference Card

```
┌─────────────────────────────────────────────────────────┐
│           Nginx DDoS Protection Limits                  │
├─────────────────────────────────────────────────────────┤
│ Rate Limit:        10 req/sec + 20 burst per IP        │
│ Connections:       10 concurrent per IP                 │
│ Request Timeout:   10 seconds                           │
│ Max Request Size:  10 MB                                │
│ Worker Capacity:   10,000 connections                   │
│ Backend Timeout:   5s connect, 10s response             │
└─────────────────────────────────────────────────────────┘
```

## Testing Checklist

- [ ] Verify rate limiting works (`ab -n 100 -c 50 http://localhost/`)
- [ ] Test connection limits (15+ simultaneous connections)
- [ ] Check timeout protection (slow request test)
- [ ] Monitor logs for "limiting" messages
- [ ] Verify backend health checks working
- [ ] Test load balancing distribution
- [ ] Check 503 responses under load
- [ ] Monitor resource usage during attack simulation
