# Observability Guide

📊 **For**: SRE and DevOps teams managing validator monitoring and automation
🎯 **Focus**: Monitoring setup, alerting, automation scripting

## Quick Monitoring Setup

### Built-in Dashboard
```bash
# Start comprehensive monitoring dashboard
validator-dashboard

# Dashboard windows:
# Window 1: Operational guidance + terminal
# Window 2: Status monitoring + live logs
# Window 3: System monitoring (htop + nethogs)

# Navigation:
# Ctrl+b + n/p  - Switch windows
# Ctrl+b + d    - Detach (keeps running)
```

### Key Health Indicators
```bash
# Essential health checks
curl -X POST -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"get_block_count","params":[],"id":1}' http://127.0.0.1:9002/
ps aux | grep validator
tail -f /home/testnet-validator/logs/validator.log
```

## Advanced Monitoring

### Log Analysis
```bash
# Real-time monitoring
tail -f /home/testnet-validator/logs/validator.log

# Error analysis
grep ERROR /home/testnet-validator/logs/validator.log | tail -20
grep WARN /home/testnet-validator/logs/validator.log | tail -10

# Performance metrics
grep "block height" /home/testnet-validator/logs/validator.log | tail -20
```

### System Metrics
```bash
# Process monitoring
htop -u testnet-validator
ps aux | grep validator

# Network monitoring
nethogs
sudo ss -tlnp | grep 9002  # RPC port
sudo ss -tlnp | grep 29001 # Gossip port

# Disk usage
df -h
du -sh /home/testnet-validator/data/
```

### Log Rotation
Automatic log rotation is configured via systemd/logrotate:
```bash
# Check logrotate configuration
cat /etc/logrotate.d/validator-testnet-validator

# Manual rotation test
sudo logrotate -d /etc/logrotate.d/validator-testnet-validator

# View rotated logs
ls -la /home/testnet-validator/logs/
```

## Automation and Scripting

### Available Functions

The `lib.sh` library provides automation-friendly functions:

```bash
# Source the library
source libs/lib.sh

# Set validator user for functions
export VALIDATOR_USER=testnet-validator
```

### Process Management Functions
```bash
# Check if validator is running
if is_validator_running "$VALIDATOR_USER"; then
    echo "Validator is running"
else
    echo "Validator is stopped"
fi

# Get validator process ID
PID=$(get_validator_pid "$VALIDATOR_USER")
echo "Validator PID: $PID"
```

### Network Health Functions
```bash
# Check RPC endpoint
if is_rpc_listening; then
    echo "RPC is responding"
fi

# Get current block height
BLOCK_HEIGHT=$(get_block_height)
echo "Current block height: $BLOCK_HEIGHT"

# Check Titan connection
TITAN_STATUS=$(get_titan_connection_status "$VALIDATOR_USER")
echo "Titan connection: $TITAN_STATUS"

# Get most recent slot
RECENT_SLOT=$(get_recent_slot "$VALIDATOR_USER")
echo "Recent slot: $RECENT_SLOT"
```

### Log Analysis Functions
```bash
# Get error counts
TOTAL_ERRORS=$(get_error_count "$VALIDATOR_USER")
RECENT_ERRORS=$(get_recent_error_count "$VALIDATOR_USER")
echo "Total errors: $TOTAL_ERRORS, Recent: $RECENT_ERRORS"

# Get recent log lines
get_recent_log_lines "$VALIDATOR_USER" 20
```

### Data Management Functions
```bash
# Check data directory sizes
DATA_SIZES=$(get_data_sizes "$VALIDATOR_USER")
echo "Data directory sizes: $DATA_SIZES"
```

### User Management Functions
```bash
# Create validator user (for automation)
create_user "new-validator"

# Deploy validator configuration
deploy_validator_operator "new-validator"

# Initialize with encrypted identity
init_validator_operator "new-validator" "testnet" "identity.age"

# Complete removal (with backup)
clobber_user "old-validator"
```

## Monitoring Integration

### Prometheus Metrics
While not built-in, you can expose metrics via RPC:

```bash
#!/bin/bash
# Custom Prometheus exporter script

VALIDATOR_USER="testnet-validator"
source /path/to/libs/lib.sh

# Export metrics in Prometheus format
echo "# HELP validator_running Whether validator is running"
echo "# TYPE validator_running gauge"
if is_validator_running "$VALIDATOR_USER"; then
    echo "validator_running 1"
else
    echo "validator_running 0"
fi

echo "# HELP validator_block_height Current block height"
echo "# TYPE validator_block_height gauge"
BLOCK_HEIGHT=$(get_block_height)
echo "validator_block_height $BLOCK_HEIGHT"

echo "# HELP validator_error_count Total error count"
echo "# TYPE validator_error_count counter"
ERROR_COUNT=$(get_error_count "$VALIDATOR_USER")
echo "validator_error_count $ERROR_COUNT"
```

### Grafana Dashboard
Example queries for Grafana dashboards:

```json
{
  "panels": [
    {
      "title": "Validator Status",
      "targets": [
        {"expr": "validator_running"}
      ]
    },
    {
      "title": "Block Height",
      "targets": [
        {"expr": "validator_block_height"}
      ]
    },
    {
      "title": "Error Rate",
      "targets": [
        {"expr": "rate(validator_error_count[5m])"}
      ]
    }
  ]
}
```

### Alerting Rules
```yaml
# Example Prometheus alerting rules
groups:
  - name: validator
    rules:
      - alert: ValidatorDown
        expr: validator_running == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Validator is not running"

      - alert: ValidatorHighErrorRate
        expr: rate(validator_error_count[5m]) > 0.1
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High error rate detected"

      - alert: ValidatorBlockHeightStale
        expr: increase(validator_block_height[10m]) == 0
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "Block height not increasing"
```

## Centralized Logging

### Log Forwarding
Forward validator logs to centralized systems:

```bash
# Example rsyslog configuration
# /etc/rsyslog.d/validator.conf
$ModLoad imfile
$InputFileName /home/testnet-validator/logs/validator.log
$InputFileTag validator:
$InputFileStateFile stat-validator
$InputFileSeverity info
$InputFileFacility local0
$InputRunFileMonitor

# Forward to central log server
local0.* @@log-server.example.com:514
```

### ELK Stack Integration
```json
# Logstash configuration for validator logs
input {
  beats {
    port => 5044
  }
}

filter {
  if [fields][type] == "validator" {
    grok {
      match => { "message" => "%{TIMESTAMP_ISO8601:timestamp} %{LOGLEVEL:level} %{GREEDYDATA:message}" }
    }

    date {
      match => [ "timestamp", "ISO8601" ]
    }
  }
}

output {
  elasticsearch {
    hosts => ["elasticsearch:9200"]
    index => "validator-logs-%{+YYYY.MM.dd}"
  }
}
```

## Health Check Scripts

### Basic Health Check
```bash
#!/bin/bash
# health-check.sh - Basic validator health check

VALIDATOR_USER="testnet-validator"
source /path/to/libs/lib.sh

EXIT_CODE=0

# Check if validator is running
if ! is_validator_running "$VALIDATOR_USER"; then
    echo "CRITICAL: Validator is not running"
    EXIT_CODE=2
fi

# Check RPC endpoint
if ! is_rpc_listening; then
    echo "CRITICAL: RPC endpoint not responding"
    EXIT_CODE=2
fi

# Check recent errors
RECENT_ERRORS=$(get_recent_error_count "$VALIDATOR_USER")
if [ "$RECENT_ERRORS" -gt 10 ]; then
    echo "WARNING: High recent error count: $RECENT_ERRORS"
    [ $EXIT_CODE -eq 0 ] && EXIT_CODE=1
fi

# Check disk space
DISK_USAGE=$(df /home/$VALIDATOR_USER | tail -1 | awk '{print $5}' | sed 's/%//')
if [ "$DISK_USAGE" -gt 90 ]; then
    echo "WARNING: High disk usage: ${DISK_USAGE}%"
    [ $EXIT_CODE -eq 0 ] && EXIT_CODE=1
fi

if [ $EXIT_CODE -eq 0 ]; then
    echo "OK: All health checks passed"
fi

exit $EXIT_CODE
```

### Nagios Integration
```bash
# /etc/nagios/nrpe.cfg
command[check_validator]=/path/to/health-check.sh
```

## Performance Monitoring

### Resource Usage Tracking
```bash
#!/bin/bash
# performance-monitor.sh - Track validator resource usage

VALIDATOR_USER="testnet-validator"

# Check if validator is running
if systemctl is-active arch-validator@$VALIDATOR_USER --quiet; then
    # CPU and memory usage
    ps -p $PID -o pid,ppid,cmd,%mem,%cpu --no-headers

    # File descriptor usage
    ls /proc/$PID/fd | wc -l

    # Network connections
    ss -p | grep $PID | wc -l

    # Data directory size
    du -sh /home/$VALIDATOR_USER/data/
fi
```

### Database Growth Monitoring
```bash
#!/bin/bash
# monitor-data-growth.sh - Track database growth over time

VALIDATOR_USER="testnet-validator"
DATA_DIR="/home/$VALIDATOR_USER/data/.arch_data"

if [ -d "$DATA_DIR" ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') $(du -sb $DATA_DIR | cut -f1)"
fi
```

## Automated Operations

### Auto-restart on Failure
```bash
#!/bin/bash
# auto-restart.sh - Automatically restart failed validator

VALIDATOR_USER="testnet-validator"
source /path/to/libs/lib.sh

if ! is_validator_running "$VALIDATOR_USER"; then
    echo "$(date): Validator not running, attempting restart"

    # Try to start validator
    systemctl start arch-validator@$VALIDATOR_USER

    sleep 10

    if is_validator_running "$VALIDATOR_USER"; then
        echo "$(date): Validator restart successful"
    else
        echo "$(date): Validator restart failed"
        # Send alert notification here
    fi
fi
```

### Automated Binary Updates
```bash
#!/bin/bash
# auto-update.sh - Automated binary updates with safety checks

VALIDATOR_USER="testnet-validator"
NEW_VERSION="v0.5.4"

# Safety checks
source /path/to/libs/lib.sh

# Check if validator is healthy before update
if ! is_validator_running "$VALIDATOR_USER"; then
    echo "ERROR: Validator not running, aborting update"
    exit 1
fi

if [ $(get_recent_error_count "$VALIDATOR_USER") -gt 5 ]; then
    echo "WARNING: High error count, aborting update"
    exit 1
fi

# Perform update
echo "Stopping validator for update..."
systemctl stop arch-validator@$VALIDATOR_USER

echo "Updating binaries..."
ARCH_VERSION=$NEW_VERSION sync-arch-bins

echo "Starting validator..."
sudo -u $VALIDATOR_USER /home/$VALIDATOR_USER/run-validator &

# Verify update
sleep 30
if is_validator_running "$VALIDATOR_USER"; then
    echo "Update successful"
else
    echo "Update failed, manual intervention required"
    exit 1
fi
```

## Troubleshooting Monitoring Issues

### Dashboard Connection Issues
```bash
# Check tmux session
tmux list-sessions | grep dashboard

# Reconnect to dashboard
tmux attach-session -t testnet-validator-dashboard

# Kill stuck dashboard
tmux kill-session -t testnet-validator-dashboard
```

### Log Analysis Issues
```bash
# Check log file permissions
ls -la /home/testnet-validator/logs/

# Check log rotation
sudo logrotate -f /etc/logrotate.d/validator-testnet-validator

# Check disk space for logs
df -h /home/testnet-validator/
```

### RPC Endpoint Issues
```bash
# Check if RPC port is bound
sudo ss -tlnp | grep 9002

# Test RPC directly
curl -X POST -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"get_block_count","params":[],"id":1}' http://127.0.0.1:9002/

# Check firewall rules
sudo ufw status | grep 9002
```

---

**Monitoring setup?** → Start with Dashboard section | **Need automation?** → See Automation section | **Integration questions?** → Check monitoring integration examples