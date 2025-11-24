# Asterisk VoIP Setup Guide

## Overview

This setup provides a VoIP infrastructure with:
- **asterisk-1** (46.62.200.187) - Primary PBX handling 80% of calls
- **asterisk-2** (95.216.205.250) - Secondary PBX handling 20% of calls
- **asterisk-balancer** (37.27.35.37) - Load balancer distributing calls

## Architecture

```
Incoming SIP Call
       |
       v
asterisk-balancer (37.27.35.37:5060)
       |
       +-- 80% --> asterisk-1 (46.62.200.187:5060)
       |
       +-- 20% --> asterisk-2 (95.216.205.250:5060)
```

## Call Behavior

When a call reaches a backend server (asterisk-1 or asterisk-2):

1. **Ring Phase**: Phone rings for 10-20 seconds (random)
2. **Outcome** (randomly determined):
   - **12%** - Busy signal
   - **33%** - No answer (timeout)
   - **55%** - Answer and play "tt-monkeys" sound for 15-45 seconds

## Deployment

### Deploy to Production

```bash
cd ansible

# Deploy all Asterisk servers
ansible-playbook playbooks/asterisk.yml

# Deploy only backends
ansible-playbook playbooks/asterisk.yml --tags backends

# Deploy only balancer
ansible-playbook playbooks/asterisk.yml --tags balancer
```

### Deploy to Docker (Local Testing)

```bash
cd ansible

# Start Docker containers
docker-compose up -d asterisk-1-test asterisk-2-test asterisk-balancer-test

# Deploy to Docker
ansible-playbook -i inventory/hosts-docker-test.yml playbooks/asterisk-docker.yml
```

## Verification

### Check Asterisk Status

```bash
# On any Asterisk server
asterisk -rx 'core show version'
asterisk -rx 'pjsip show endpoints'
asterisk -rx 'dialplan show incoming'
```

### Check Load Balancer

```bash
# On asterisk-balancer
asterisk -rx 'pjsip show endpoints'
asterisk -rx 'dialplan show balancer'
```

### Monitor Active Calls

```bash
# Show current channels
asterisk -rx 'core show channels'

# Verbose logging
asterisk -rvvv
```

## Configuration Files

### Backend Servers (asterisk-1, asterisk-2)

Located in `ansible/roles/asterisk/templates/`:

- **pjsip.conf.j2** - SIP transport and endpoint configuration
- **extensions.conf.j2** - Dialplan with call outcome logic
- **rtp.conf.j2** - RTP port configuration

### Load Balancer (asterisk-balancer)

Located in `ansible/roles/asterisk-balancer/templates/`:

- **pjsip.conf.j2** - Backend endpoints with health checks
- **extensions.conf.j2** - Load balancing dialplan (80/20 weighted)
- **rtp.conf.j2** - RTP port configuration

## Dialplan Logic

### Backend Dialplan (extensions.conf)

```
[incoming]
; Call arrives
exten => _X.,1,NoOp(Incoming call)
 same => n,Set(OUTCOME=${RAND(1,100)})
 same => n,Set(RING_TIME=${RAND(10,20)})
 same => n,Ringing()
 same => n,Wait(${RING_TIME})

 ; 1-12 = busy (12%)
 same => n,GotoIf($[${OUTCOME} <= 12]?busy)
 ; 13-45 = no answer (33%)
 same => n,GotoIf($[${OUTCOME} <= 45]?noanswer)
 ; 46-100 = answer (55%)
 same => n,Goto(answer)

 same => n(busy),Busy(5)
 same => n,Hangup()

 same => n(noanswer),Hangup(18)

 same => n(answer),Answer()
 same => n,Set(PLAY_TIME=${RAND(15,45)})
 same => n(playloop),Playback(tt-monkeys)
 same => n,GotoIf($[${EPOCH} < ${END_TIME}]?playloop)
 same => n,Hangup()
```

### Balancer Dialplan

```
[balancer]
; Weighted random selection: 1-4 = asterisk-1 (80%), 5 = asterisk-2 (20%)
exten => _X.,1,Set(WEIGHT_ROLL=${RAND(1,5)})
 same => n,GotoIf($[${WEIGHT_ROLL} <= 4]?route_ast1:route_ast2)
 same => n(route_ast1),Dial(PJSIP/${EXTEN}@asterisk-1,60)
 same => n,Hangup()
 same => n(route_ast2),Dial(PJSIP/${EXTEN}@asterisk-2,60)
 same => n,Hangup()
```

## Troubleshooting

### No SIP Registration

```bash
# Check if PJSIP is loaded
asterisk -rx 'module show like pjsip'

# Check transport status
asterisk -rx 'pjsip show transports'

# Check endpoint status
asterisk -rx 'pjsip show endpoints'
```

### Calls Not Routing

```bash
# Enable SIP debugging
asterisk -rx 'pjsip set logger on'

# Check dialplan
asterisk -rx 'dialplan show'

# Test dialplan
asterisk -rx 'dialplan show incoming@incoming'
```

### Audio Issues

```bash
# Check RTP configuration
asterisk -rx 'rtp show settings'

# Verify codecs
asterisk -rx 'core show codecs'
```

## Docker Testing

### Container IPs

| Container | IP |
|-----------|-----|
| asterisk-1-test | 172.20.0.40 |
| asterisk-2-test | 172.20.0.41 |
| asterisk-balancer-test | 172.20.0.42 |

### Local Ports

| Service | Port |
|---------|------|
| Balancer | localhost:5060 |
| asterisk-1 | localhost:5061 |
| asterisk-2 | localhost:5062 |

### Testing Commands

```bash
# Check all containers
for c in asterisk-1-test asterisk-2-test asterisk-balancer-test; do
  echo "=== $c ==="
  docker exec $c asterisk -rx 'core show version'
done

# Check balancer endpoints
docker exec asterisk-balancer-test asterisk -rx 'pjsip show endpoints'
```

## SIP Protocol Basics

### Call Flow

1. **INVITE** - Initiate call
2. **100 Trying** - Request received
3. **180 Ringing** - Phone ringing
4. **200 OK** - Call answered (or 486 Busy / timeout)
5. **ACK** - Acknowledgment
6. **RTP** - Audio stream
7. **BYE** - End call
8. **200 OK** - Confirmation

### Ports

- **5060/UDP** - SIP signaling
- **10000-20000/UDP** - RTP media (audio)

## References

- [Asterisk Documentation](https://docs.asterisk.org/)
- [PJSIP Configuration](https://docs.asterisk.org/Asterisk_22_Documentation/API_Documentation/Dialplan_Applications/PJSIP_Configuration_Module/)
- [Dialplan Basics](https://docs.asterisk.org/Configuration/Dialplan/)
