# InfluxDB Introduction and Core Concepts

## What is InfluxDB?

InfluxDB is a **time series database** (TSDB) designed specifically for storing and querying time-stamped data. It excels at handling metrics, events, and analytics data that changes over time.

### Use Cases

- **System Monitoring**: CPU, memory, disk usage over time
- **Application Metrics**: Request rates, response times, error counts
- **IoT Sensors**: Temperature, pressure, humidity readings
- **Log Analytics**: Event counts, error rates, user activity
- **Business Metrics**: Sales, user signups, revenue tracking

## Why Time Series Database?

Traditional relational databases (SQL) aren't optimized for time series data:

| Feature | Traditional DB | Time Series DB |
|---------|---------------|----------------|
| Write Speed | Moderate | Very Fast (100K+ points/sec) |
| Compression | Limited | High (10-20x) |
| Retention Policies | Manual | Automatic |
| Time-based Queries | Complex | Native |
| Downsampling | Manual | Built-in |

## InfluxDB Versions

### InfluxDB 2.x (Current)

- **Unified API**: Single port (8086) for all operations
- **Query Languages**: Flux (primary), InfluxQL (legacy)
- **Built-in UI**: Web interface for queries and visualization
- **Organizations & Buckets**: Multi-tenancy support
- **Free & Open Source**: MIT/Apache 2.0 license

### InfluxDB 3.0 Core

- **SQL Support**: Standard SQL queries
- **Parquet Storage**: Efficient columnar format
- **Unlimited Cardinality**: No tag/series limits
- **Apache Arrow**: Fast in-memory analytics

*Note: This project uses InfluxDB 2.7 (stable, mature)*

## Core Concepts

### 1. Data Model

InfluxDB organizes data into:

```
Organization (Tenant)
  └── Bucket (Database)
      └── Measurement (Table)
          ├── Tags (Indexed metadata)
          ├── Fields (Actual values)
          └── Timestamp (Required)
```

#### Example Data Point

```
cpu_usage,host=server01,region=us-east value=75.5 1699545600000000000
│         │                             │    │
Measurement  Tags (indexed)           Field  Timestamp (nanoseconds)
```

### 2. Measurement

The "table" or "metric" name. Groups related data together.

**Examples:**
- `cpu_usage`
- `memory_usage`
- `http_requests`
- `temperature`

### 3. Tags

**Indexed metadata** for filtering and grouping. Use tags for:

- Low cardinality values (limited unique values)
- Data you'll filter by
- Dimensions for grouping

**Good Tags:**
- `host=server01` (10-100 servers)
- `region=us-east` (5-10 regions)
- `environment=production` (3-5 environments)
- `service=api` (10-50 services)

**Bad Tags (high cardinality):**
- `user_id=12345` (millions of users)
- `request_id=abc123` (unique per request)
- `timestamp_str=2025-11-09` (use timestamp instead)

### 4. Fields

**Unindexed values** - the actual data you want to store.

**Field Types:**
- `Float`: Decimal numbers (default)
- `Integer`: Whole numbers
- `String`: Text values
- `Boolean`: true/false

**Examples:**
```
cpu_usage value=75.5          # Float
http_requests count=1234      # Integer  
error_message text="timeout"  # String
is_healthy status=true        # Boolean
```

### 5. Timestamp

Every point must have a timestamp. InfluxDB stores in **nanoseconds** since Unix epoch.

**Precision Levels:**
- `ns`: Nanoseconds (1/1,000,000,000 second)
- `us`: Microseconds (1/1,000,000 second)
- `ms`: Milliseconds (1/1,000 second)
- `s`: Seconds

### 6. Series

A **series** is a unique combination of measurement + tags:

```
cpu_usage,host=server01,region=us-east
cpu_usage,host=server02,region=us-east
cpu_usage,host=server01,region=us-west
```

This creates **3 different series**.

**Series Cardinality**: Total number of unique series in a bucket.
- Low cardinality: 1-10K series (good)
- High cardinality: 1M+ series (problematic)

## Organizations and Buckets

### Organization

A **tenant** or workspace. Isolates data between different teams/projects.

```
Organization: "company_name"
  ├── Bucket: "production_metrics"
  ├── Bucket: "staging_metrics"
  └── Bucket: "logs"
```

### Bucket

A **database** where time series data is stored.

**Properties:**
- **Name**: Unique identifier
- **Retention**: How long to keep data (e.g., 30 days, infinite)
- **Shard Duration**: Time range per storage file

**Example:**
```bash
# Create bucket with 30-day retention
influx bucket create \
  --name system_logs \
  --org debian_monitoring \
  --retention 30d
```

## Authentication

### Tokens

InfluxDB 2.x uses **API tokens** for authentication:

```bash
# All requests need a token
curl -H "Authorization: Token YOUR_TOKEN" \
  http://localhost:8086/api/v2/buckets
```

**Token Types:**
- **All Access**: Full permissions (admin)
- **Read/Write**: Limited to specific buckets
- **Read-Only**: Query only

### Creating Tokens

```bash
# Via CLI
influx auth create \
  --org debian_monitoring \
  --read-bucket system_logs \
  --write-bucket system_logs

# Via UI
# http://localhost:8086 → Load Data → API Tokens
```

## Data Retention

InfluxDB automatically deletes old data based on retention policies:

```
Bucket: system_logs
Retention: 60 days

Today: Nov 9, 2025
  ├── Keep: Oct 10, 2025 - Nov 9, 2025
  └── Delete: < Oct 10, 2025
```

**Retention Options:**
- `1h`: 1 hour
- `7d`: 7 days
- `30d`: 30 days
- `1y`: 1 year
- `infinite`: Never delete (default)

## Query Languages

### Flux (Primary)

Functional language designed for time series:

```flux
from(bucket: "system_logs")
  |> range(start: -1h)
  |> filter(fn: (r) => r._measurement == "cpu_usage")
  |> filter(fn: (r) => r.host == "server01")
  |> mean()
```

**Characteristics:**
- Functional, pipeline-based
- Powerful transformations
- Built-in functions for time series
- Can join multiple buckets

### InfluxQL (Legacy on version 2, primary on version 3)

SQL-like query language:

```sql
SELECT mean(value) 
FROM cpu_usage 
WHERE time > now() - 1h 
  AND host = 'server01'
```

**Characteristics:**
- Familiar SQL syntax
- Easier for SQL users
- Less powerful than Flux
- Being phased out

## Common Operations

### Writing Data

#### Line Protocol

Text-based format for writing data:

```
measurement,tag1=value1,tag2=value2 field1=value1,field2=value2 timestamp
```

**Example:**
```
cpu_usage,host=server01,region=us-east value=75.5,cores=8 1699545600000000000
```

#### Via HTTP API

```bash
curl -X POST "http://localhost:8086/api/v2/write?org=myorg&bucket=mybucket" \
  -H "Authorization: Token YOUR_TOKEN" \
  -H "Content-Type: text/plain" \
  --data-binary "cpu_usage,host=server01 value=75.5"
```

### Querying Data

#### Via HTTP API

```bash
curl -X POST "http://localhost:8086/api/v2/query?org=myorg" \
  -H "Authorization: Token YOUR_TOKEN" \
  -H "Content-Type: application/vnd.flux" \
  --data 'from(bucket:"mybucket") |> range(start: -1h)'
```

#### Via CLI

```bash
influx query \
  --org myorg \
  --token YOUR_TOKEN \
  'from(bucket:"mybucket") |> range(start: -1h)'
```

## Basic Flux Queries

### 1. Select All Recent Data

```flux
from(bucket: "system_logs")
  |> range(start: -1h)
```

### 2. Filter by Measurement

```flux
from(bucket: "system_logs")
  |> range(start: -1h)
  |> filter(fn: (r) => r._measurement == "cpu_usage")
```

### 3. Filter by Tags

```flux
from(bucket: "system_logs")
  |> range(start: -1h)
  |> filter(fn: (r) => r._measurement == "cpu_usage")
  |> filter(fn: (r) => r.host == "server01")
```

### 4. Aggregations

```flux
// Average
from(bucket: "system_logs")
  |> range(start: -1h)
  |> filter(fn: (r) => r._measurement == "cpu_usage")
  |> mean()

// Count
from(bucket: "system_logs")
  |> range(start: -1h)
  |> count()

// Max/Min
from(bucket: "system_logs")
  |> range(start: -1h)
  |> max()
```

### 5. Time Windows

```flux
from(bucket: "system_logs")
  |> range(start: -24h)
  |> filter(fn: (r) => r._measurement == "cpu_usage")
  |> aggregateWindow(every: 5m, fn: mean)
```

### 6. Group By

```flux
from(bucket: "system_logs")
  |> range(start: -1h)
  |> filter(fn: (r) => r._measurement == "cpu_usage")
  |> group(columns: ["host"])
  |> mean()
```

### 7. Sorting and Limiting

```flux
from(bucket: "system_logs")
  |> range(start: -1h)
  |> filter(fn: (r) => r._measurement == "cpu_usage")
  |> sort(columns: ["_time"], desc: true)
  |> limit(n: 10)
```

## Best Practices

### 1. Tag Design

**DO:**
- Use tags for dimensions you'll filter by
- Keep tag cardinality low (< 100K unique combinations)
- Use short tag keys and values

**DON'T:**
- Use tags for unique values (UUIDs, emails)
- Use tags for high cardinality data (user IDs)
- Use tags for data that changes frequently

### 2. Field Design

**DO:**
- Use fields for measured values
- Use appropriate field types (float for decimals)
- Use fields for high cardinality data

**DON'T:**
- Use fields for filtering (slow, unindexed)
- Mix field types (causes conflicts)

### 3. Measurement Design

**DO:**
- Use descriptive names (`cpu_usage`, not `cpu`)
- Group related metrics in same measurement
- Keep measurement names consistent

**DON'T:**
- Use measurement names as tags
- Create too many measurements (< 1000 ideal)

### 4. Retention

**DO:**
- Set appropriate retention (30d, 90d, 1y)
- Use shorter retention for high-volume data
- Consider downsampling old data

**DON'T:**
- Use infinite retention by default
- Keep raw data forever

### 5. Query Performance

**DO:**
- Use time ranges (`range(start: -1h)`)
- Filter on tags first
- Use aggregateWindow for downsampling
- Limit result size

**DON'T:**
- Query entire bucket without time range
- Filter on fields (slow)
- Return millions of points

## Monitoring InfluxDB

### Health Check

```bash
curl http://localhost:8086/health
```

### Metrics

```bash
curl http://localhost:8086/metrics
```

### Database Size

```bash
influx bucket list --org myorg
```

## Common Issues

### High Cardinality

**Problem**: Too many unique series
**Solution**: Reduce tag combinations, use fields instead

### Slow Queries

**Problem**: Queries taking too long
**Solution**: Add time range, filter on tags, use aggregateWindow

### Memory Usage

**Problem**: High memory consumption
**Solution**: Reduce retention, enable compression, increase shard duration

## Resources

- Official Documentation: https://docs.influxdata.com/influxdb/v2/
- Flux Language: https://docs.influxdata.com/flux/v0/
- Community Forum: https://community.influxdata.com/
- GitHub: https://github.com/influxdata/influxdb
- Docker Image: https://hub.docker.com/_/influxdb
