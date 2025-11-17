# Asterisk Load Balancer: Kamailio Implementation

## Change Summary

The asterisk-balancer container has been updated to use **Kamailio** instead of OpenSIPS.

### Reason for Change

OpenSIPS packages are not available in the default Debian 12 repositories, which was causing build failures. Kamailio is readily available in Debian repos and provides equivalent SIP load balancing functionality.

## What is Kamailio?

Kamailio (formerly OpenSER) is a high-performance, open-source SIP server that can handle:
- SIP routing and load balancing
- Millions of calls
- Complex routing logic
- Real-time communications

It's widely used in production VoIP systems and is very similar to OpenSIPS in functionality.

## Technical Differences

### Installation
- **Before**: `opensips` and multiple module packages (not available in Debian 12)
- **After**: `kamailio` and `kamailio-extra-modules` (available in Debian repos)

### Configuration File
- **Before**: `/etc/opensips/opensips.cfg`
- **After**: `/etc/kamailio/kamailio.cfg`

### Commands
- **Before**: `opensips-cli -x mi ds_list`
- **After**: `kamctl dispatcher dump`

### Dispatcher Format
- **Before**: `1 sip:asterisk-1:5060 0 80`
- **After**: `1 sip:asterisk-1:5060 0 0 weight=80`

## Functionality

The load balancing behavior remains **exactly the same**:
- ✅ 80% of calls go to asterisk-1
- ✅ 20% of calls go to asterisk-2
- ✅ Health checking of backend servers
- ✅ Automatic failover if server is down
- ✅ SIP routing and proxy functionality

## Testing Commands

### Check Dispatcher Status
```bash
# View configured dispatchers
docker exec -it asterisk-balancer kamctl dispatcher dump

# Example output:
# SET:: 1
#  URI:: sip:asterisk-1:5060 FLAGS:: 0 PRIORITY:: 0 ATTRS:: weight=80
#  URI:: sip:asterisk-2:5060 FLAGS:: 0 PRIORITY:: 0 ATTRS:: weight=20
```

### Check Kamailio Status
```bash
# Check if Kamailio is running
docker exec -it asterisk-balancer service kamailio status

# View statistics
docker exec -it asterisk-balancer kamctl stats

# View active SIP sessions
docker exec -it asterisk-balancer kamctl fifo profile_get_size calls
```

### Monitor Calls in Real-Time
```bash
# Watch syslog for SIP messages
docker exec -it asterisk-balancer tail -f /var/log/syslog | grep kamailio

# You'll see messages like:
# "Dispatching call to sip:asterisk-1:5060"
# "Dispatching call to sip:asterisk-2:5060"
```

### Test Load Distribution
```bash
# Run 100 test calls
docker exec -it sipp sipp -sn uac asterisk-balancer:5060 -m 100 -r 5

# Check distribution on asterisk servers
docker exec -it asterisk-1 asterisk -rx "core show channels"
docker exec -it asterisk-2 asterisk -rx "core show channels"

# You should see approximately 80 calls on asterisk-1 and 20 on asterisk-2
```

## Configuration Details

### Kamailio Config (/etc/kamailio/kamailio.cfg)

Key features:
- **Listens on**: UDP and TCP port 5060
- **Max hops**: 10 (prevents loops)
- **Dispatcher module**: Loads backend servers from dispatcher.list
- **Health checks**: Pings backends every 30 seconds
- **Routing**: Uses weighted round-robin (algorithm 9)

### Dispatcher List (/etc/kamailio/dispatcher.list)

Format:
```
setid destination flags priority attributes
```

Our configuration:
```
1 sip:asterisk-1:5060 0 0 weight=80
1 sip:asterisk-2:5060 0 0 weight=20
```

Where:
- `1` = Set ID (group of destinations)
- `sip:asterisk-X:5060` = SIP URI of backend
- First `0` = Flags (0 = active)
- Second `0` = Priority
- `weight=80` = Weight for load balancing (80% vs 20%)

## Troubleshooting

### Kamailio Not Starting

```bash
# Check logs
docker exec -it asterisk-balancer tail -50 /var/log/syslog

# Test configuration syntax
docker exec -it asterisk-balancer kamailio -c

# Check if process is running
docker exec -it asterisk-balancer ps aux | grep kamailio
```

### Dispatchers Not Loading

```bash
# Check dispatcher file syntax
docker exec -it asterisk-balancer cat /etc/kamailio/dispatcher.list

# Reload dispatchers
docker exec -it asterisk-balancer kamctl dispatcher reload

# View loaded dispatchers
docker exec -it asterisk-balancer kamctl dispatcher dump
```

### Calls Not Being Balanced

```bash
# Monitor real-time SIP traffic
docker exec -it asterisk-balancer kamctl trap

# Check if backends are marked as active
docker exec -it asterisk-balancer kamctl dispatcher dump
# Look for FLAGS:: 0 (active) vs FLAGS:: 1 (inactive)

# Test backend connectivity
docker exec -it asterisk-balancer ping asterisk-1
docker exec -it asterisk-balancer ping asterisk-2
```

## Performance

Kamailio is designed for high performance:
- Can handle **100,000+ calls** on modest hardware
- Very low latency (microseconds for routing decisions)
- Efficient memory usage
- Built-in health checking doesn't impact performance

For our test setup with 2 Asterisk backends, Kamailio will have no performance limitations.

## Migration Notes

If you had any custom OpenSIPS configuration, here are the equivalents in Kamailio:

| OpenSIPS | Kamailio | Notes |
|----------|----------|-------|
| `opensips.cfg` | `kamailio.cfg` | Similar syntax |
| `opensips-cli -x mi` | `kamctl` | Command-line tool |
| `ds_select_dst("1", "4")` | `ds_select_dst("1", "9")` | Algorithm 9 = weighted |
| Module: `signaling` | Module: `sl` | Reply module |
| `$avp(dsdst)` | Same | AVP variables compatible |

## Documentation

- **Kamailio Wiki**: https://www.kamailio.org/wiki/
- **Dispatcher Module**: https://www.kamailio.org/docs/modules/stable/modules/dispatcher.html
- **kamctl Command**: https://www.kamailio.org/docs/tutorials/kamctl-basics/

## Summary

✅ **Benefits of Kamailio**:
- Available in Debian repos (easy to install)
- Actively maintained and widely used
- Excellent documentation
- Production-proven

✅ **Same Functionality**:
- 80/20 load balancing works identically
- Health checking enabled
- SIP routing logic equivalent
- No changes needed to Asterisk configuration

🎯 **Impact**: Zero impact on functionality - just a different (equally capable) SIP load balancer implementation.
