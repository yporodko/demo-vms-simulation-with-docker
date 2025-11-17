# Asterisk Setup Guide

## What is Asterisk?

Asterisk is an open-source PBX (Private Branch Exchange) - essentially a phone system that routes calls. It handles VoIP (Voice over IP) calls using protocols like SIP (Session Initiation Protocol).

## How This Setup Works

### Architecture

```
SIPp (Test Client)
    ↓ (sends SIP INVITE)
Kamailio Load Balancer (asterisk-balancer)
    ↓ 80%          ↓ 20%
Asterisk-1    Asterisk-2
```

### Components

1. **Kamailio (asterisk-balancer)**: SIP load balancer that distributes incoming calls
   - Receives SIP calls on port 5060
   - Routes 80% to asterisk-1, 20% to asterisk-2
   - Uses weighted round-robin distribution

2. **Asterisk-1 & Asterisk-2**: VoIP PBX servers
   - Handle incoming SIP calls
   - Execute dialplan logic (like a phone system script)
   - Play audio files (tt-monkeys sound)

3. **SIPp**: SIP testing tool
   - Simulates phone calls
   - Can generate load tests
   - Sends SIP INVITE messages

## Understanding SIP Call Flow

A typical SIP call has these steps:

1. **INVITE** - "I want to make a call"
2. **100 Trying** - "I received your request"
3. **180 Ringing** - "The phone is ringing"
4. **200 OK** - "Call answered"
5. **ACK** - "Acknowledged"
6. **RTP Stream** - Actual voice/audio data
7. **BYE** - "Hanging up"
8. **200 OK** - "Goodbye confirmed"

## Dialplan Logic (extensions.conf)

The dialplan defines what happens when a call arrives:

```
1. Call arrives → Ring for 10-20 seconds (random)
2. Generate random number (1-100):
   - 1-12:  Return BUSY signal (12%)
   - 13-45: Return NO ANSWER (33%)
   - 46-100: ANSWER and play tt-monkeys (55%)
3. If answered, play sound for 15-45 seconds (random)
4. Hangup
```

## Testing the Setup

### Basic Test (1 call)

```bash
# SSH into SIPp container
docker exec -it sipp bash

# Make a single test call
sipp -sn uac asterisk-balancer:5060 -m 1
```

**What this does:**
- `-sn uac` = Use built-in "User Agent Client" scenario
- `asterisk-balancer:5060` = Target SIP server
- `-m 1` = Make 1 call

### Load Test (Multiple calls)

```bash
# Make 100 calls at 5 calls per second
sipp -sn uac asterisk-balancer:5060 -m 100 -r 5

# Run calls for 60 seconds
sipp -sn uac asterisk-balancer:5060 -d 60000 -r 2
```

**Parameters:**
- `-m 100` = Maximum 100 calls
- `-r 5` = Rate of 5 calls per second
- `-d 60000` = Duration of 60 seconds (in milliseconds)

### Monitor Call Distribution

```bash
# Watch Asterisk-1 calls
docker exec -it asterisk-1 asterisk -rvvv

# In Asterisk CLI, run:
core show channels

# Watch Asterisk-2 calls
docker exec -it asterisk-2 asterisk -rvvv
```

After running 100 calls, you should see:
- ~80 calls handled by asterisk-1
- ~20 calls handled by asterisk-2

## Common SIPp Scenarios

### 1. Simple Call (UAC - User Agent Client)
```bash
sipp -sn uac asterisk-balancer:5060 -m 10
```

### 2. Call with Statistics
```bash
sipp -sn uac asterisk-balancer:5060 -m 100 -r 5 -trace_stat
```

### 3. Call with Message Details
```bash
sipp -sn uac asterisk-balancer:5060 -m 10 -trace_msg
```

### 4. Stress Test
```bash
sipp -sn uac asterisk-balancer:5060 -r 10 -l 50 -d 120000
```
- `-l 50` = Limit to 50 simultaneous calls
- `-r 10` = 10 new calls per second

## Understanding Results

### Expected Call Outcomes

If you make 100 calls, you should see approximately:
- 12 calls with BUSY status
- 33 calls with NO ANSWER
- 55 calls ANSWERED

### Checking Asterisk Logs

```bash
# View Asterisk-1 logs
docker exec -it asterisk-1 tail -f /var/log/asterisk/messages

# View what's happening in real-time
docker exec -it asterisk-1 asterisk -rvvv
```

In the logs, look for:
- `Call result: BUSY`
- `Call result: NO ANSWER`
- `Call result: ANSWERED`

## SIP Commands Reference

### In Asterisk CLI
```bash
# Show active calls
core show channels

# Show SIP peers (connections)
sip show peers

# Show detailed SIP channels
sip show channels

# Reload SIP configuration
sip reload

# Show dialplan
dialplan show
```

### Testing Load Balancer

```bash
# Check Kamailio dispatcher list
docker exec -it asterisk-balancer kamctl dispatcher dump

# Check Kamailio status
docker exec -it asterisk-balancer kamctl stats
```

## Troubleshooting

### No calls reaching Asterisk

1. Check if Kamailio is running:
```bash
docker exec -it asterisk-balancer ps aux | grep kamailio
```

2. Check Asterisk is listening:
```bash
docker exec -it asterisk-1 asterisk -rx "sip show settings" | grep "SIP Port"
```

3. Check network connectivity:
```bash
docker exec -it sipp ping asterisk-balancer
```

### Calls failing immediately

1. Check Asterisk dialplan:
```bash
docker exec -it asterisk-1 asterisk -rx "dialplan show"
```

2. Watch SIP messages:
```bash
docker exec -it asterisk-1 asterisk -rvvv
# Then in CLI:
sip set debug on
```

### Load balancing not distributing correctly

1. Check dispatcher list weights:
```bash
cat asterisk-balancer/config/dispatcher.list
```

Should show:
```
1 sip:asterisk-1:5060 0 80
1 sip:asterisk-2:5060 0 20
```

## Audio Files

The `tt-monkeys` audio file is part of Asterisk's core sound package. It's a standard test sound file included with Asterisk.

Other available sounds:
- `demo-congrats`
- `hello-world`
- `tt-weasels`

## Advanced: Custom SIP Scenario

Create `/scenarios/custom.xml` in the SIPp container and use:

```bash
sipp -sf /scenarios/custom.xml asterisk-balancer:5060
```

## Performance Metrics

Monitor system during load test:

```bash
# Watch resources
docker stats

# Monitor Asterisk channels
watch -n 1 'docker exec asterisk-1 asterisk -rx "core show channels"'

# Monitor call rate
docker exec -it sipp sipp -sn uac asterisk-balancer:5060 -r 10 -m 1000 -trace_stat
```

## Summary

This setup simulates a production VoIP infrastructure where:
1. Calls come in through a load balancer (Kamailio)
2. Calls are distributed 80/20 to two Asterisk servers
3. Each Asterisk server processes calls with realistic behavior (ringing, busy, no answer, answered with audio)
4. SIPp generates test traffic to verify the setup

The configuration demonstrates:
- SIP load balancing with weighted distribution
- Asterisk dialplan programming
- Call flow management
- Audio playback in VoIP calls
