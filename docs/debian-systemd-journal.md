# Understanding Debian's systemd Journal Logging

## Overview

Debian Linux uses **systemd-journald** as its central logging service. Understanding how systemd writes to the journal is essential for proper log classification and monitoring.

## Journal Structure

### Log Entry Components

Every journal entry consists of:

1. **Message**: The actual log content
2. **Priority**: Syslog-style severity level (0-7)
3. **Metadata Fields**: Additional contextual information

### Standard Fields

systemd automatically adds these fields to every entry:

- `_HOSTNAME`: System hostname
- `_TRANSPORT`: How the log arrived (journal, syslog, kernel, etc.)
- `_PID`: Process ID
- `_UID`, `_GID`: User and group IDs
- `_COMM`: Command name
- `_EXE`: Executable path
- `_SYSTEMD_UNIT`: Systemd unit that generated the log
- `SYSLOG_IDENTIFIER`: Traditional syslog identifier
- `MESSAGE`: The log message itself
- `PRIORITY`: Severity level (0-7)

## Priority Levels (RFC 5424)

systemd uses the standard syslog priority scheme:

| Code | Name      | Description | Use Case |
|------|-----------|-------------|----------|
| 0    | EMERG     | Emergency   | System is unusable |
| 1    | ALERT     | Alert       | Action must be taken immediately |
| 2    | CRIT      | Critical    | Critical conditions |
| 3    | ERR       | Error       | Error conditions |
| 4    | WARNING   | Warning     | Warning conditions |
| 5    | NOTICE    | Notice      | Normal but significant |
| 6    | INFO      | Info        | Informational messages |
| 7    | DEBUG     | Debug       | Debug-level messages |

## How Applications Write to Journal

### Method 1: Native Journal API

Applications can write directly to the journal using `libsystemd`:

```c
sd_journal_send("MESSAGE=Application started",
                "PRIORITY=6",
                "CUSTOM_FIELD=value",
                NULL);
```

### Method 2: Standard Output/Error

systemd captures stdout/stderr from services:

- **stdout** → Priority 6 (INFO)
- **stderr** → Priority 3 (ERR)

### Method 3: Syslog Compatibility

Legacy applications using syslog are automatically captured:

```c
syslog(LOG_WARNING, "This is a warning");
```

### Method 4: Kernel Messages

Kernel logs (`dmesg`) are automatically imported with priorities:

- Kernel panics → Priority 0 (EMERG)
- Errors → Priority 3 (ERR)
- Warnings → Priority 4 (WARNING)
- Info → Priority 6 (INFO)

### Method 5: Logger

Another way to paint logs on journal is to use logger binary:

```
logger -p user.err "TEST ERROR: Disk operation failed on /dev/sda1"
logger -p user.warning "TEST WARNING: High CPU usage detected - 85%"
logger -p user.crit "TEST CRITICAL: Memory exhaustion detected - system swap at 95%"
logger -p user.info "TEST INFO: Network interface eth0 UP - 1000Mbps full duplex"
logger -p user.emerg "TEST EMERGENCY: Critical System compromised - total fail"
```

## Common Log Sources

### System Services

```bash
# SSH daemon logs
SYSLOG_IDENTIFIER=sshd
_SYSTEMD_UNIT=ssh.service
PRIORITY=6  # Successful connections
PRIORITY=4  # Failed authentication attempts
```

### Kernel

```bash
# Hardware events
_TRANSPORT=kernel
SYSLOG_IDENTIFIER=kernel
PRIORITY varies by event type
```

### User Applications

```bash
# Custom application
SYSLOG_IDENTIFIER=myapp
_SYSTEMD_UNIT=myapp.service
PRIORITY set by application
```

### Desktop Environment (X11/Wayland)

```bash
# Display server logs
SYSLOG_IDENTIFIER=Xorg
MESSAGE contains X11 error codes (II, WW, EE)
PRIORITY usually 6 (INFO) or 4 (WARNING)
```

## Log Classification Patterns

### By Service Type

1. **Network Services**: sshd, systemd-networkd, NetworkManager
2. **Hardware Events**: kernel, udev, systemd-udevd
3. **Authentication**: sshd, login, systemd-logind, polkitd
4. **Storage**: kernel (disk errors), systemd-journald
5. **Display**: Xorg, GNOME, KDE services
6. **Firewall**: kernel (iptables/nftables)

### By Priority Distribution

In a healthy Debian system:

- **90%**: Priority 6 (INFO) - Normal operations
- **5-8%**: Priority 4-5 (WARNING/NOTICE) - Non-critical issues
- **1-2%**: Priority 3 (ERR) - Recoverable errors
- **<1%**: Priority 0-2 (CRIT/ALERT/EMERG) - Critical issues

### Message Pattern Examples

```bash
# Firewall logs
MESSAGE="IN=eth0 OUT= SRC=192.168.1.100 DST=192.168.1.1"
Pattern: Network packet details
Priority: Usually 6 (INFO)

# Hardware errors
MESSAGE="USB device disconnected"
Pattern: Device-related keywords
Priority: 4 (WARNING) or 3 (ERR)

# Authentication
MESSAGE="Accepted publickey for user"
Pattern: Auth-related keywords
Priority: 6 (INFO) success, 4 (WARNING) failure

# X11 Display
MESSAGE="(II) XINPUT: Adding device Mouse"
Pattern: X11 severity codes (II, WW, EE)
Priority: 6 (INFO)
```

## Querying the Journal

### By Priority

```bash
# Critical and errors only
journalctl -p err

# Warnings and above
journalctl -p warning

# Specific priority
journalctl PRIORITY=3
```

### By Service

```bash
# Specific systemd unit
journalctl -u ssh.service

# Specific identifier
journalctl SYSLOG_IDENTIFIER=kernel
```

### Time Range

```bash
# Last hour
journalctl --since "1 hour ago"

# Specific date
journalctl --since "2025-11-09 00:00:00"
```

### Combined Filters

```bash
# SSH errors in last 24h
journalctl -u ssh.service -p err --since today
```

## Best Practices for Log Classification

1. **Use Priority Field**: Always present, standardized across all sources
2. **Check SYSLOG_IDENTIFIER**: Identifies the log source reliably
3. **Parse MESSAGE Content**: Extract specific patterns (IPs, device IDs, error codes)
4. **Combine Multiple Fields**: Use priority + identifier + message patterns for accuracy
5. **Handle Special Cases**: X11 logs use internal codes (II/WW/EE) that don't map directly to priority

## Integration with Monitoring

When forwarding logs to monitoring systems (InfluxDB, Elasticsearch, etc.):

1. **Preserve Priority**: Essential for alerting and filtering
2. **Add Custom Categories**: Enrich logs with domain-specific classifications
3. **Extract Metadata**: Parse MESSAGE field for actionable data
4. **Normalize Timestamps**: Convert to consistent timezone
5. **Tag by Source**: Use SYSLOG_IDENTIFIER and _SYSTEMD_UNIT as tags

## References

- [systemd-journald Documentation](https://www.freedesktop.org/software/systemd/man/systemd-journald.service.html)
- [RFC 5424 - Syslog Protocol](https://tools.ietf.org/html/rfc5424)
- [Journal Fields Reference](https://www.freedesktop.org/software/systemd/man/systemd.journal-fields.html)
