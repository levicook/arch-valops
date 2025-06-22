# Validator Monitoring Guide

This guide covers comprehensive monitoring and observability for Arch Network validators using the valops toolkit.

## Quick Start

```bash
# Start the monitoring dashboard
VALIDATOR_USER=testnet-validator ./validator-dashboard

# Check validator status quickly
source lib.sh
export VALIDATOR_USER=testnet-validator
./validator-dashboard-helpers/status-check
```

## Dashboard Overview

The `validator-dashboard` provides a comprehensive monitoring interface through tmux sessions.

### Window Layout

**Window 1: Welcome & Operations**
- Shows operational guidance and best practices
- Provides interactive bash terminal for ad-hoc commands
- Access to help system with `show-help`

**Window 2: Dashboard**
- **Top pane**: Continuous status monitoring (refreshes every 10 seconds)
- **Bottom pane**: Live validator logs with real-time updates

**Window 3: System Monitoring**
- **Top pane**: `htop` for system resources (CPU, memory, processes)
- **Bottom pane**: `nethogs` for network usage by process

### Navigation

```bash
# tmux navigation commands
Ctrl+b then n          # Switch to next window
Ctrl+b then p          # Switch to previous window  
Ctrl+b then 1/2/3      # Switch to specific window
Ctrl+b then arrow keys # Switch between panes within window
Ctrl+b then d          # Detach (dashboard keeps running)

# Reattach to existing session
tmux attach -t testnet-validator-dashboard
```

## Status Monitoring

The status monitor provides comprehensive health information with color-coded indicators.

### Status Indicators

**🔄 Process Status:**
- ✅ Green: Validator running normally
- ❌ Red: Validator stopped or crashed
- ⚠ Yellow: Multiple validator processes detected

**🌐 Network Status:**
- ✅ Green: RPC listening and responding
- ❌ Red: RPC port not listening or unresponsive
- ⚠ Yellow: RPC responding with errors

**🌐 Network Health:**
- ✅ Green: Connected to Titan network with recent activity
- ❌ Red: Disconnected from Titan network
- ⚠ Yellow: Connection status unknown or no recent activity

**📊 Recent Activity:**
- ✅ Green: No errors, stable operation
- ❌ Red: Recent errors detected (last hour)
- ⚠ Yellow: Historical errors or frequent restarts

### Understanding Status Output

```
=== ARCH VALIDATOR STATUS ===

🔄 PROCESS STATUS:
  ✅ Validator RUNNING (PID: 12345, uptime: 2-03:45:12)

🌐 NETWORK STATUS:
  ✅ RPC listening on :9002
  ✅ RPC responding

🌐 NETWORK HEALTH:
  ✅ Titan network: connected
  ✅ Local block height: 272
  ✅ Recent slot activity: 1234567

💾 DATA STATUS:
  Ledger: 1.2G | Total: 2.4G

📊 RECENT ACTIVITY:
  ✅ No recent errors
  ✅ Stable run (no restarts detected)
  Latest activity:
    2025-01-15 14:30:25 validator: Processing slot 1234567
    2025-01-15 14:30:26 validator: Block height: 272
```

## Health Check Procedures

### Quick Health Check

```bash
source lib.sh
export VALIDATOR_USER=testnet-validator

# Basic health indicators
echo "Process: $(is_validator_running "$VALIDATOR_USER" && echo "Running" || echo "Stopped")"
echo "RPC: $(is_rpc_listening && echo "Listening" || echo "Down")"
echo "Block Height: $(get_block_height)"
echo "Network: $(get_titan_connection_status "$VALIDATOR_USER")"
```

### Comprehensive Health Assessment

```bash
# Run the detailed status check
./validator-dashboard-helpers/status-check

# Or use individual utility functions
source lib.sh
export VALIDATOR_USER=testnet-validator

# Process information
PID=$(get_validator_pid "$VALIDATOR_USER")
UPTIME=$(get_validator_uptime "$VALIDATOR_USER" "$PID")
echo "Validator PID: $PID, Uptime: $UPTIME"

# Network health
BLOCK_HEIGHT=$(get_block_height)
TITAN_STATUS=$(get_titan_connection_status "$VALIDATOR_USER")
RECENT_SLOT=$(get_recent_slot "$VALIDATOR_USER")
echo "Block: $BLOCK_HEIGHT, Network: $TITAN_STATUS, Slot: $RECENT_SLOT"

# Error analysis
ERROR_COUNT=$(get_error_count "$VALIDATOR_USER")
RECENT_ERRORS=$(get_recent_error_count "$VALIDATOR_USER")
echo "Errors: $ERROR_COUNT total, $RECENT_ERRORS recent"
```

## Alert Conditions

### Critical Alerts (Immediate Attention Required)

1. **Validator Process Stopped**
   ```bash
   if ! is_validator_running "$VALIDATOR_USER"; then
       echo "CRITICAL: Validator process not running"
   fi
   ```

2. **RPC Server Down**
   ```bash
   if ! is_rpc_listening; then
       echo "CRITICAL: RPC server not responding"
   fi
   ```

3. **Network Disconnection**
   ```bash
   if [ "$(get_titan_connection_status "$VALIDATOR_USER")" = "disconnected" ]; then
       echo "CRITICAL: Disconnected from Titan network"
   fi
   ```

### Warning Conditions (Monitor Closely)

1. **Multiple Validator Processes**
   ```bash
   COUNT=$(get_validator_pid_count "$VALIDATOR_USER")
   if [ "$COUNT" -gt 1 ]; then
       echo "WARNING: Multiple validator processes ($COUNT)"
   fi
   ```

2. **High Error Rate**
   ```bash
   RECENT_ERRORS=$(get_recent_error_count "$VALIDATOR_USER")
   if [ "$RECENT_ERRORS" -gt 5 ]; then
       echo "WARNING: High error rate ($RECENT_ERRORS in last hour)"
   fi
   ```

3. **No Recent Activity**
   ```bash
   RECENT_SLOT=$(get_recent_slot "$VALIDATOR_USER")
   if [ "$RECENT_SLOT" = "unknown" ]; then
       echo "WARNING: No recent slot activity"
   fi
   ```

### Monitoring Script Example

```bash
#!/bin/bash
source lib.sh
export VALIDATOR_USER=testnet-validator

check_alerts() {
    local alerts=0
    
    # Critical checks
    if ! is_validator_running "$VALIDATOR_USER"; then
        echo "$(date): CRITICAL - Validator stopped"
        ((alerts++))
    fi
    
    if ! is_rpc_listening; then
        echo "$(date): CRITICAL - RPC down"
        ((alerts++))
    fi
    
    if [ "$(get_titan_connection_status "$VALIDATOR_USER")" = "disconnected" ]; then
        echo "$(date): CRITICAL - Network disconnected"
        ((alerts++))
    fi
    
    # Warning checks
    local recent_errors=$(get_recent_error_count "$VALIDATOR_USER")
    if [ "$recent_errors" != "unknown" ] && [ "$recent_errors" -gt 5 ]; then
        echo "$(date): WARNING - High error rate: $recent_errors"
        ((alerts++))
    fi
    
    return $alerts
}

# Run continuous monitoring
while true; do
    if ! check_alerts; then
        echo "$(date): All systems normal"
    fi
    sleep 60
done
```

## Log Analysis

### Live Log Monitoring

```bash
# Monitor live logs in dashboard (Window 2, bottom pane)
# Or manually:
sudo su - testnet-validator -c "tail -f logs/validator.log"
```

### Log Search Patterns

```bash
# Error analysis
grep ERROR /home/testnet-validator/logs/validator.log | tail -10

# Network connectivity
grep -i titan /home/testnet-validator/logs/validator.log | tail -10

# Startup/restart events
grep -E "Starting|Initializing|startup" /home/testnet-validator/logs/validator.log

# Slot activity
grep "slot [0-9]*" /home/testnet-validator/logs/validator.log | tail -10

# Block height progression
grep "block height" /home/testnet-validator/logs/validator.log | tail -5
```

### Log Rotation

Logs are automatically rotated daily with 7-day retention:

```bash
# Check log rotation configuration
cat /etc/logrotate.d/validator-testnet-validator

# Test log rotation
sudo logrotate -d /etc/logrotate.d/validator-testnet-validator

# Manual rotation (if needed)
sudo logrotate -f /etc/logrotate.d/validator-testnet-validator
```

## Performance Monitoring

### System Resources

Monitor system resources through the dashboard (Window 3) or manually:

```bash
# CPU and memory usage
htop

# Network usage by process
sudo nethogs

# Disk usage
df -h
du -sh /home/testnet-validator/data/

# Network connections
sudo ss -tlnp | grep 9002
```

### Validator-Specific Metrics

```bash
source lib.sh
export VALIDATOR_USER=testnet-validator

# Data growth tracking
DATA_SIZES=$(get_data_sizes "$VALIDATOR_USER")
echo "Current data sizes: $DATA_SIZES"

# Process uptime and stability
PID=$(get_validator_pid "$VALIDATOR_USER")
UPTIME=$(get_validator_uptime "$VALIDATOR_USER" "$PID")
RESTARTS=$(get_restart_count "$VALIDATOR_USER")
echo "Uptime: $UPTIME, Restarts: $RESTARTS"

# Network performance
BLOCK_HEIGHT=$(get_block_height)
echo "Block height: $BLOCK_HEIGHT"
```

## Troubleshooting Guide

### Validator Won't Start

1. **Check Environment Setup**
   ```bash
   # Verify user exists
   id testnet-validator
   
   # Check home directory
   sudo -u testnet-validator ls -la /home/testnet-validator/
   
   # Verify binaries
   which validator
   ```

2. **Review Startup Logs**
   ```bash
   # Check recent startup attempts
   grep "run-validator:" /home/testnet-validator/logs/validator.log | tail -5
   
   # Look for error messages
   grep ERROR /home/testnet-validator/logs/validator.log | tail -10
   ```

3. **Test Manual Start**
   ```bash
   # Try starting manually to see immediate errors
   sudo -u testnet-validator /home/testnet-validator/run-validator
   ```

### Performance Issues

1. **High CPU Usage**
   - Monitor with `htop` in dashboard Window 3
   - Check for multiple validator processes: `get_validator_pid_count "$VALIDATOR_USER"`
   - Review system load and other processes

2. **High Memory Usage**
   - Monitor memory consumption in `htop`
   - Check data directory growth: `get_data_sizes "$VALIDATOR_USER"`
   - Review validator logs for memory-related errors

3. **Network Issues**
   - Check Titan connectivity: `get_titan_connection_status "$VALIDATOR_USER"`
   - Monitor network usage with `nethogs`
   - Test RPC endpoint: `get_block_height`

### Connection Problems

1. **RPC Not Responding**
   ```bash
   # Check if port is listening
   sudo ss -tlnp | grep 9002
   
   # Test RPC manually
   curl -X POST -H "Content-Type: application/json" \
     -d '{"jsonrpc":"2.0","method":"get_block_count","params":[],"id":1}' \
     http://127.0.0.1:9002/
   ```

2. **Titan Network Disconnection**
   ```bash
   # Check connection logs
   grep -i "titan\|connection" /home/testnet-validator/logs/validator.log | tail -10
   
   # Verify network connectivity
   curl -s https://titan-public-http.test.arch.network | head -5
   ```

### Data Issues

1. **Rapid Disk Growth**
   ```bash
   # Monitor data directory sizes
   watch -n 10 "du -sh /home/testnet-validator/data/"
   
   # Check for log file growth
   ls -lah /home/testnet-validator/logs/
   ```

2. **Corrupted Data**
   ```bash
   # Stop validator
   sudo -u testnet-validator /home/testnet-validator/halt-validator
   
   # Check data directory integrity
   sudo -u testnet-validator ls -la /home/testnet-validator/data/.arch_data/
   
   # Review logs for corruption errors
   grep -i "corrupt\|error\|fail" /home/testnet-validator/logs/validator.log
   ```

## Best Practices

### Daily Monitoring Routine

1. **Check Dashboard Status** (2 minutes)
   - Launch dashboard: `VALIDATOR_USER=testnet-validator ./validator-dashboard`
   - Review all status indicators in Window 2
   - Check system resources in Window 3

2. **Review Logs** (3 minutes)
   - Scan recent log entries for errors
   - Check for any unusual patterns or warnings
   - Verify normal slot processing activity

3. **Validate Network Health** (2 minutes)
   - Confirm Titan network connectivity
   - Check block height progression
   - Verify RPC endpoint responsiveness

### Weekly Maintenance

1. **Log Analysis**
   ```bash
   # Review error trends
   grep ERROR /home/testnet-validator/logs/validator.log* | wc -l
   
   # Check restart patterns
   grep -E "Starting|Initializing" /home/testnet-validator/logs/validator.log* | wc -l
   ```

2. **Performance Review**
   ```bash
   # Check data growth trends
   du -sh /home/testnet-validator/data/.arch_data/testnet/ledger
   
   # Review system resource usage patterns
   # (Use historical monitoring data if available)
   ```

3. **Configuration Validation**
   ```bash
   # Verify log rotation is working
   ls -la /home/testnet-validator/logs/
   
   # Check system updates
   sudo apt list --upgradable
   ```

### Alert Setup

Consider setting up external monitoring that uses the utility functions:

```bash
#!/bin/bash
# Example cron job script (run every 5 minutes)
# */5 * * * * /path/to/validator-alert-check.sh

source /path/to/valops/lib.sh
export VALIDATOR_USER=testnet-validator

if ! is_validator_running "$VALIDATOR_USER"; then
    # Send alert (email, Slack, etc.)
    echo "Validator down at $(date)" | mail -s "ALERT: Validator Down" admin@example.com
fi

if ! is_rpc_listening; then
    echo "RPC down at $(date)" | mail -s "ALERT: RPC Down" admin@example.com
fi
```

## Advanced Monitoring

### Custom Dashboards

You can create custom monitoring solutions using the utility functions:

```bash
#!/bin/bash
# Custom monitoring dashboard
source lib.sh
export VALIDATOR_USER=testnet-validator

while true; do
    clear
    echo "=== Custom Validator Monitor ==="
    echo "Time: $(date)"
    echo "Process: $(is_validator_running "$VALIDATOR_USER" && echo "✓ Running" || echo "✗ Stopped")"
    echo "RPC: $(is_rpc_listening && echo "✓ Listening" || echo "✗ Down")"
    echo "Block: $(get_block_height)"
    echo "Network: $(get_titan_connection_status "$VALIDATOR_USER")"
    echo "Errors: $(get_error_count "$VALIDATOR_USER") total, $(get_recent_error_count "$VALIDATOR_USER") recent"
    echo "Data: $(get_data_sizes "$VALIDATOR_USER")"
    sleep 10
done
```

### Integration with External Systems

The utility functions can be integrated with monitoring systems like Prometheus, Grafana, or custom APIs:

```bash
#!/bin/bash
# Export metrics for external monitoring
source lib.sh
export VALIDATOR_USER=testnet-validator

# Generate metrics in Prometheus format
echo "# HELP validator_running Whether validator process is running"
echo "# TYPE validator_running gauge"
echo "validator_running $(is_validator_running "$VALIDATOR_USER" && echo 1 || echo 0)"

echo "# HELP validator_block_height Current block height"
echo "# TYPE validator_block_height gauge"
BLOCK_HEIGHT=$(get_block_height)
if [ "$BLOCK_HEIGHT" != "unknown" ]; then
    echo "validator_block_height $BLOCK_HEIGHT"
fi

echo "# HELP validator_error_count Total error count"
echo "# TYPE validator_error_count counter"
echo "validator_error_count $(get_error_count "$VALIDATOR_USER")"
```

This monitoring system provides comprehensive observability for your Arch Network validator with minimal overhead and maximum reliability. 