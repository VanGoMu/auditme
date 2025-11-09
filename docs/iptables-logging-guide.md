# iptables Logging Guide

## Overview

This guide explains how to use iptables LOG target for network traffic monitoring and auditing, and how to integrate it with the auditme monitoring stack.

## Basic Command Explanation

### `iptables -A INPUT -j LOG --log-prefix='[netfilter]'`

**Command breakdown:**

- **`-A INPUT`**: Appends a rule to the end of the INPUT chain (incoming traffic)
- **`-j LOG`**: Jumps to the LOG target, which logs packet information to the kernel log
- **`--log-prefix='[netfilter]'`**: Adds a prefix to each log entry for easier searching/filtering

### What it does:
Logs information about **all** packets arriving at the network interface, including:
- Source and destination IP addresses
- Port numbers
- Protocol (TCP/UDP/ICMP)
- Network interface
- TCP flags

### ⚠️ Important:
This rule does **NOT block or accept** traffic, it only logs it. The packet continues processing through subsequent rules.

## Advanced Configurations and Best Practices

### 1. Selective Logging (More Efficient)

Log only specific traffic to reduce noise and improve performance:

```bash
# Log only SSH packets
iptables -A INPUT -p tcp --dport 22 -j LOG --log-prefix='[SSH] '

# Log only failed connection attempts
iptables -A INPUT -m state --state INVALID -j LOG --log-prefix='[INVALID] '

# Log dropped packets at the end of the chain
iptables -A INPUT -j LOG --log-prefix='[DROPPED] ' --log-level 4
iptables -A INPUT -j DROP
```

### 2. Rate Limiting (Prevent Log Flooding)

Prevent log spam from high-traffic scenarios:

```bash
# Limit to 5 logs per minute
iptables -A INPUT -m limit --limit 5/min -j LOG --log-prefix='[netfilter] '

# With burst for temporary spikes
iptables -A INPUT -m limit --limit 5/min --limit-burst 10 -j LOG --log-prefix='[netfilter] '
```

### 3. Detailed Log Levels

Control log severity using syslog levels:

```bash
# --log-level (0-7, equivalent to syslog)
# 0=emerg, 1=alert, 2=crit, 3=err, 4=warning, 5=notice, 6=info, 7=debug

iptables -A INPUT -j LOG --log-prefix='[CRITICAL] ' --log-level 2
iptables -A INPUT -j LOG --log-prefix='[WARNING] ' --log-level 4
iptables -A INPUT -j LOG --log-prefix='[INFO] ' --log-level 6
```

### 4. Additional Log Information

Include more detailed packet information:

```bash
# Include TCP headers
iptables -A INPUT -p tcp -j LOG --log-prefix='[TCP] ' --log-tcp-options

# Include IP options
iptables -A INPUT -j LOG --log-prefix='[IP] ' --log-ip-options

# Show UID of the process (for local traffic)
iptables -A OUTPUT -j LOG --log-prefix='[OUT] ' --log-uid

# Include TCP sequence numbers
iptables -A INPUT -p tcp -j LOG --log-prefix='[TCP-SEQ] ' --log-tcp-sequence
```

### 5. Complete Recommended Configuration

A production-ready logging setup:

```bash
# Create custom logging chain
iptables -N LOGGING

# Log with rate limiting
iptables -A LOGGING -m limit --limit 5/min -j LOG \
    --log-prefix='[iptables-drop] ' \
    --log-level 4

# Drop after logging
iptables -A LOGGING -j DROP

# Use the chain for suspicious traffic
iptables -A INPUT -p tcp --dport 23 -j LOGGING   # Telnet
iptables -A INPUT -p tcp --dport 3389 -j LOGGING # RDP
iptables -A INPUT -p tcp --dport 445 -j LOGGING  # SMB

# Log port scanning attempts
iptables -A INPUT -p tcp --tcp-flags ALL NONE -j LOGGING
iptables -A INPUT -p tcp --tcp-flags ALL ALL -j LOGGING
```

## Common Use Cases

### 1. Security Monitoring

```bash
# Log SSH brute force attempts
iptables -A INPUT -p tcp --dport 22 -m state --state NEW \
    -m recent --update --seconds 60 --hitcount 4 \
    -j LOG --log-prefix='[SSH-BRUTE] '

# Log port scans
iptables -A INPUT -p tcp --tcp-flags SYN,ACK,FIN,RST RST \
    -m limit --limit 1/s \
    -j LOG --log-prefix='[PORT-SCAN] '

# Log ping floods
iptables -A INPUT -p icmp --icmp-type echo-request \
    -m limit --limit 1/s \
    -j LOG --log-prefix='[PING-FLOOD] '
```

### 2. Traffic Analysis

```bash
# Log HTTP/HTTPS traffic
iptables -A INPUT -p tcp -m multiport --dports 80,443 \
    -j LOG --log-prefix='[WEB] '

# Log DNS queries
iptables -A OUTPUT -p udp --dport 53 \
    -j LOG --log-prefix='[DNS] '

# Log database connections
iptables -A INPUT -p tcp -m multiport --dports 3306,5432,27017 \
    -j LOG --log-prefix='[DATABASE] '
```

### 3. Debugging Network Issues

```bash
# Log all traffic to/from specific IP
iptables -A INPUT -s 192.168.1.100 -j LOG --log-prefix='[DEBUG-IN] '
iptables -A OUTPUT -d 192.168.1.100 -j LOG --log-prefix='[DEBUG-OUT] '

# Log rejected packets
iptables -A INPUT -j LOG --log-prefix='[REJECT] '
iptables -A INPUT -j REJECT
```

## Integration with auditme Monitoring Stack

### Step 1: Configure Log Destination

Create `/etc/rsyslog.d/10-iptables.conf`:

```conf
# Send iptables logs to separate file
:msg,contains,"[netfilter]" /var/log/iptables.log
:msg,contains,"[iptables" /var/log/iptables.log
& stop

# Optionally, send to remote syslog server
# :msg,contains,"[iptables]" @@remote-server:514
```

Restart rsyslog:

```bash
sudo systemctl restart rsyslog
```

### Step 2: Configure Fluent Bit Input

Add to `fluent-bit/fluent-bit.conf`:

```ini
[INPUT]
    Name              tail
    Path              /var/log/iptables.log
    Tag               iptables
    Parser            iptables
    DB                /var/log/fluentbit-iptables.db
    Mem_Buf_Limit     5MB
    Skip_Long_Lines   On
    Refresh_Interval  5

[FILTER]
    Name              lua
    Match             iptables
    script            /fluent-bit/etc/bucket_router.lua
    call              enrich_and_route
```

### Step 3: Create iptables Parser

Add to `fluent-bit/fluent-bit.conf` or create separate parser file:

```ini
[PARSER]
    Name              iptables
    Format            regex
    Regex             ^\[(?<prefix>[^\]]+)\]\s+IN=(?<in_interface>\S*)\s+OUT=(?<out_interface>\S*)\s+.*SRC=(?<src_ip>\S+)\s+DST=(?<dst_ip>\S+).*PROTO=(?<protocol>\S+).*SPT=(?<src_port>\d+).*DPT=(?<dst_port>\d+)
    Time_Key          time
    Time_Format       %b %d %H:%M:%S
```

### Step 4: Enhance Lua Script

Add firewall category detection to `fluent-bit/bucket_router.lua`:

```lua
-- Around line 30, add to category detection
local identifier = record["syslog_identifier"] or record["_SYSTEMD_UNIT"] or ""
local msg_lower = string.lower(msg)

-- Detect firewall logs
if identifier == "kernel" or identifier == "iptables" then
    if msg_lower:match("%[netfilter%]") 
        or msg_lower:match("%[iptables%]") 
        or msg_lower:match("iptables:")
        or msg_lower:match("nf_conntrack")
        or msg_lower:match("%[ssh%-brute%]")
        or msg_lower:match("%[port%-scan%]")
        or msg_lower:match("%[dropped%]") then
        record["category"] = "firewall"
    end
end
```

### Step 5: Create Grafana Dashboard Panel

Add a new panel to monitor firewall events:

**Query:**
```flux
from(bucket: "system_logs")
  |> range(start: v.timeRangeStart, stop: v.timeRangeStop)
  |> filter(fn: (r) => r._measurement == "system.journal" and r.category == "firewall")
  |> aggregateWindow(every: 1m, fn: count)
```

## Log Format Example

A typical iptables log entry looks like:

```
Nov  9 10:30:15 hostname kernel: [netfilter] IN=eth0 OUT= MAC=00:11:22:33:44:55:66:77:88:99:aa:bb:cc:dd SRC=192.168.1.100 DST=192.168.1.1 LEN=60 TOS=0x00 PREC=0x00 TTL=64 ID=12345 DF PROTO=TCP SPT=54321 DPT=80 WINDOW=29200 RES=0x00 SYN URGP=0
```

**Parsed fields:**
- `IN`: Incoming interface (eth0)
- `OUT`: Outgoing interface (empty for INPUT chain)
- `SRC`: Source IP address
- `DST`: Destination IP address
- `PROTO`: Protocol (TCP/UDP/ICMP)
- `SPT`: Source port
- `DPT`: Destination port
- `SYN`: TCP flags

## Performance Considerations

### Advantages ✅

- **Non-invasive**: Does not affect packet flow
- **Debugging**: Excellent for troubleshooting firewall rules
- **Auditing**: Detailed record of network activity
- **Threat Detection**: Identify attack patterns and anomalies

### Disadvantages ⚠️

- **High Volume**: Can generate massive amounts of logs on busy networks
- **Performance Impact**: Logging has CPU and disk I/O overhead
- **Storage**: Logs can grow rapidly and consume disk space
- **Privacy**: May log sensitive information in packet contents

### Best Practices

1. **Always use rate limiting** in production environments
2. **Log selectively** - only what you need
3. **Rotate logs frequently** - use logrotate
4. **Monitor disk space** - set up alerts
5. **Use separate log files** - easier management and analysis
6. **Consider log levels** - match severity appropriately
7. **Test before deploying** - verify logging doesn't impact performance

## Log Rotation Configuration

Create `/etc/logrotate.d/iptables`:

```conf
/var/log/iptables.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 0640 root adm
    sharedscripts
    postrotate
        /usr/bin/systemctl reload rsyslog > /dev/null 2>&1 || true
    endscript
}
```

## Troubleshooting

### Logs not appearing

1. Check if iptables rules are active:
   ```bash
   sudo iptables -L -v -n
   ```

2. Verify kernel logging is enabled:
   ```bash
   dmesg | tail
   ```

3. Check rsyslog configuration:
   ```bash
   sudo rsyslogd -N1  # Test configuration
   sudo systemctl status rsyslog
   ```

4. Monitor log file:
   ```bash
   sudo tail -f /var/log/iptables.log
   ```

### Too many logs

1. Add rate limiting to existing rules:
   ```bash
   iptables -I INPUT 1 -m limit --limit 5/min -j LOG --log-prefix='[rate-limited] '
   ```

2. Make logging more selective by adding specific conditions

3. Increase log rotation frequency

### Missing packet information

Use additional flags to capture more details:
```bash
iptables -A INPUT -j LOG \
    --log-prefix='[detailed] ' \
    --log-level 7 \
    --log-tcp-options \
    --log-ip-options \
    --log-tcp-sequence
```

## Security Considerations

1. **Sensitive Data**: Logs may contain IP addresses and port information - consider privacy regulations
2. **Log Tampering**: Protect log files with appropriate permissions (0640)
3. **Remote Logging**: Use encrypted transport (TLS) for remote syslog
4. **Access Control**: Restrict who can view firewall logs
5. **Retention Policies**: Define how long to keep logs based on compliance requirements

## Example: Complete Production Setup

```bash
#!/bin/bash
# Complete iptables logging setup script

# Flush existing rules (be careful!)
# iptables -F

# Create logging chains
iptables -N LOG_ACCEPT
iptables -N LOG_DROP
iptables -N LOG_REJECT

# Configure log chains with rate limiting
iptables -A LOG_ACCEPT -m limit --limit 2/min -j LOG --log-prefix='[ACCEPT] ' --log-level 6
iptables -A LOG_ACCEPT -j ACCEPT

iptables -A LOG_DROP -m limit --limit 2/min -j LOG --log-prefix='[DROP] ' --log-level 4
iptables -A LOG_DROP -j DROP

iptables -A LOG_REJECT -m limit --limit 2/min -j LOG --log-prefix='[REJECT] ' --log-level 4
iptables -A LOG_REJECT -j REJECT

# Allow established connections (no logging)
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Log and accept SSH
iptables -A INPUT -p tcp --dport 22 -j LOG_ACCEPT

# Log and accept HTTP/HTTPS
iptables -A INPUT -p tcp -m multiport --dports 80,443 -j LOG_ACCEPT

# Log and drop everything else
iptables -A INPUT -j LOG_DROP

# Save rules
iptables-save > /etc/iptables/rules.v4
```

## References

- [iptables man page](https://linux.die.net/man/8/iptables)
- [Netfilter documentation](https://www.netfilter.org/documentation/)
- [rsyslog documentation](https://www.rsyslog.com/doc/)
- [Fluent Bit documentation](https://docs.fluentbit.io/)

## See Also

- [Debian systemd Journal Guide](./debian-systemd-journal.md)
- [Fluent Bit Configuration Guide](./fluent-bit-guide.md)
- [Security Monitoring Best Practices](./security-best-practices.md)
