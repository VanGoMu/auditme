# Fluent Bit Guide

## What is Fluent Bit?

Fluent Bit is a lightweight and high-performance log processor and forwarder. It's designed to collect, parse, filter, and route logs and metrics from different sources to various destinations. It's the smaller sibling of Fluentd, consuming only ~450KB of memory.

## Core Concepts

### Pipeline Architecture

Fluent Bit follows a simple pipeline architecture:

```
INPUT → FILTER → OUTPUT
```

1. **INPUT**: Collects data from various sources
2. **FILTER**: Processes, parses, and enriches data
3. **OUTPUT**: Sends data to destinations

### Configuration File Structure

Fluent Bit uses a simple configuration format with sections:

```ini
[SERVICE]
    Key    Value

[INPUT]
    Name    plugin_name
    Key     Value

[FILTER]
    Name    plugin_name
    Match   pattern
    Key     Value

[OUTPUT]
    Name    plugin_name
    Match   pattern
    Key     Value
```

## Common Input Plugins

### 1. Systemd

Reads logs from systemd journal:

```ini
[INPUT]
    Name                systemd
    Tag                 system.logs
    Path                /var/log/journal
    Systemd_Filter      PRIORITY=3    # Filter by priority
    Read_From_Tail      On            # Start from end
    Strip_Underscores   On            # Remove _ prefix
```

**Key Options:**
- `Systemd_Filter`: Filter by systemd fields (can use multiple)
- `Systemd_Filter_Type`: `And` or `Or` for multiple filters
- `Read_From_Tail`: Start reading from the end (`On`) or beginning (`Off`)

### 2. Tail

Reads from log files like `tail -f`:

```ini
[INPUT]
    Name              tail
    Tag               app.logs
    Path              /var/log/app/*.log
    Parser            json
    Refresh_Interval  5
```

### 3. CPU, Memory, Disk

System metrics:

```ini
[INPUT]
    Name   cpu
    Tag    system.cpu

[INPUT]
    Name   mem
    Tag    system.memory
```

## Filter Plugins

### 1. Grep

Filter records based on pattern matching:

```ini
[FILTER]
    Name    grep
    Match   system.*
    Regex   message error|critical
```

**Operations:**
- `Regex`: Keep records matching pattern
- `Exclude`: Remove records matching pattern

### 2. Record Modifier

Add, remove, or modify record fields:

```ini
[FILTER]
    Name             record_modifier
    Match            *
    Record           hostname ${HOSTNAME}
    Record           environment production
    Remove_key       sensitive_field
```

### 3. Parser

Parse unstructured logs into structured data:

```ini
[FILTER]
    Name         parser
    Match        app.*
    Key_Name     log
    Parser       json
    Reserve_Data On
```

### 4. Lua

Execute custom Lua scripts for complex processing:

```ini
[FILTER]
    Name    lua
    Match   *
    script  /path/to/script.lua
    call    function_name
```

## Output Plugins

### 1. InfluxDB

Send data to InfluxDB v2:

```ini
[OUTPUT]
    Name          influxdb
    Match         system.*
    Host          influxdb
    Port          8086
    Org           my_org
    Bucket        my_bucket
    HTTP_Token    ${TOKEN}
    Tag_Keys      host service
    Sequence_Tag  _seq
```

**Key Options:**
- `Tag_Keys`: Record fields to use as InfluxDB tags
- `Sequence_Tag`: Field name for sequence number
- `HTTP_Token`: Authentication token (use env vars)

### 2. File

Write to local files:

```ini
[OUTPUT]
    Name    file
    Match   *
    Path    /tmp/logs
    Format  json
```

### 3. Stdout

Print to console (useful for debugging):

```ini
[OUTPUT]
    Name    stdout
    Match   *
    Format  json_lines
```

## Pattern Matching

Use wildcard patterns to match tags:

- `*` - Matches all tags
- `system.*` - Matches `system.cpu`, `system.memory`, etc.
- `app.prod.*` - Matches `app.prod.api`, `app.prod.web`, etc.

## Environment Variables

Use environment variables for sensitive data:

```ini
[OUTPUT]
    Name      influxdb
    Host      ${INFLUX_HOST}
    Bucket    ${INFLUX_BUCKET}
    HTTP_Token ${INFLUX_TOKEN}
```

Set in Docker:

```yaml
environment:
  - INFLUX_HOST=influxdb
  - INFLUX_TOKEN=secret-token
```

## Service Configuration

The `[SERVICE]` section configures Fluent Bit itself:

```ini
[SERVICE]
    Flush        5              # Flush interval (seconds)
    Daemon       Off            # Run as daemon
    Log_Level    info           # debug, info, warn, error
    HTTP_Server  On             # Enable metrics API
    HTTP_Listen  0.0.0.0
    HTTP_Port    2020
```

### Metrics API

When HTTP_Server is enabled, access metrics at:

```
http://localhost:2020/api/v1/metrics
```

## Best Practices

### 1. Use Tags Wisely

Organize data with meaningful tags:

```ini
[INPUT]
    Name    systemd
    Tag     system.journal.${HOSTNAME}
```

### 2. Filter Early

Apply filters as early as possible to reduce processing:

```ini
# Filter at input level when possible
[INPUT]
    Name            systemd
    Systemd_Filter  PRIORITY=0
    Systemd_Filter  PRIORITY=1
    Systemd_Filter  PRIORITY=2
```

### 3. Use Environment Variables

Never hardcode secrets:

```ini
# Bad
HTTP_Token    my-secret-token

# Good
HTTP_Token    ${INFLUX_TOKEN}
```

### 4. Enable Buffering

For reliable delivery:

```ini
[OUTPUT]
    Name          influxdb
    Match         *
    Retry_Limit   5
```

### 5. Monitor Performance

Check metrics regularly:

```bash
curl http://localhost:2020/api/v1/metrics
```

## Debugging

### Enable Debug Logging

```ini
[SERVICE]
    Log_Level    debug
```

### Output to Stdout

Add temporary stdout output:

```ini
[OUTPUT]
    Name    stdout
    Match   *
```

### Check Container Logs

```bash
docker logs fluent-bit -f
```

## Common Use Cases

### 1. System Monitoring

```ini
[INPUT]
    Name       systemd
    Tag        system.journal
    Path       /var/log/journal
    Read_From_Tail On

[FILTER]
    Name             record_modifier
    Match            *
    Record           hostname ${HOSTNAME}

[OUTPUT]
    Name       influxdb
    Match      system.*
    Host       influxdb
    Bucket     system_logs
```

### 2. Application Logs

```ini
[INPUT]
    Name    tail
    Tag     app.access
    Path    /var/log/nginx/access.log
    Parser  nginx

[FILTER]
    Name    grep
    Match   app.access
    Regex   status ^[45]

[OUTPUT]
    Name       file
    Match      app.access
    Path       /tmp/errors.log
```

### 3. Multi-Destination Routing

```ini
[INPUT]
    Name    systemd
    Tag     system.journal

[OUTPUT]
    Name    influxdb
    Match   system.*
    Host    influxdb

[OUTPUT]
    Name    file
    Match   system.*
    Path    /backup/logs
```

## Performance Tuning

### Memory Buffer

```ini
[SERVICE]
    storage.path              /var/log/flb-storage/
    storage.sync              normal
    storage.checksum          off
    storage.max_chunks_up     128
    storage.backlog.mem_limit 5M
```

### Flush Interval

Balance between latency and efficiency:

```ini
[SERVICE]
    Flush    5    # 5 seconds (default)
    # Flush  1    # Lower latency, more CPU
    # Flush  30   # Higher latency, less CPU
```

## Resources

- Official Documentation: https://docs.fluentbit.io
- Configuration Examples: https://github.com/fluent/fluent-bit/tree/master/conf
- Plugin List: https://docs.fluentbit.io/manual/pipeline/inputs
