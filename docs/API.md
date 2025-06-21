# Common.sh API Reference

This document provides a complete reference for the utility functions available in `common.sh`.

## Usage

```bash
# Source the library
source common.sh

# Set required environment variable
export VALIDATOR_USER=testnet-validator

# Use functions
if is_validator_running "$VALIDATOR_USER"; then
    echo "Validator is running with PID: $(get_validator_pid "$VALIDATOR_USER")"
fi
```

## Process Management Functions

### `get_validator_pid(username)`
Returns the process ID of the running validator, or empty string if not running.

**Parameters:**
- `username`: Validator user account name

**Returns:**
- Process ID (numeric string) if validator is running
- Empty string if no validator process found

**Example:**
```bash
PID=$(get_validator_pid "testnet-validator")
if [ -n "$PID" ]; then
    echo "Validator running with PID: $PID"
fi
```

### `get_validator_pid_count(username)`
Returns the number of validator processes running.

**Parameters:**
- `username`: Validator user account name

**Returns:**
- Count of validator processes (numeric string, "0" if none)

**Example:**
```bash
COUNT=$(get_validator_pid_count "testnet-validator")
if [ "$COUNT" -gt 1 ]; then
    echo "Warning: Multiple validator processes detected ($COUNT)"
fi
```

### `get_validator_uptime(username, pid)`
Returns the uptime of a specific validator process.

**Parameters:**
- `username`: Validator user account name
- `pid`: Process ID to check

**Returns:**
- Uptime string (e.g., "2-03:45:12") or "unknown" if unavailable

**Example:**
```bash
PID=$(get_validator_pid "testnet-validator")
if [ -n "$PID" ]; then
    UPTIME=$(get_validator_uptime "testnet-validator" "$PID")
    echo "Validator uptime: $UPTIME"
fi
```

### `is_validator_running(username)`
Boolean check if validator is running.

**Parameters:**
- `username`: Validator user account name

**Returns:**
- Exit code 0 if validator is running
- Exit code 1 if validator is not running

**Example:**
```bash
if is_validator_running "testnet-validator"; then
    echo "✓ Validator is running"
else
    echo "✗ Validator is stopped"
fi
```

## Network Functions

### `is_rpc_listening()`
Boolean check if RPC server is listening on port 9002.

**Parameters:** None

**Returns:**
- Exit code 0 if RPC port is listening
- Exit code 1 if RPC port is not listening

**Example:**
```bash
if is_rpc_listening; then
    echo "✓ RPC server is listening"
else
    echo "✗ RPC server is not listening"
fi
```

### `get_rpc_response(method)`
Makes an RPC call and returns the raw JSON response.

**Parameters:**
- `method`: RPC method name (e.g., "get_block_count")

**Returns:**
- Raw JSON response from RPC server
- Empty string if request fails or times out

**Example:**
```bash
RESPONSE=$(get_rpc_response "get_block_count")
if [ -n "$RESPONSE" ]; then
    echo "RPC response: $RESPONSE"
fi
```

### `get_block_height()`
Returns the current block height from the RPC server.

**Parameters:** None

**Returns:**
- Block height (numeric string) if available
- "unknown" if RPC is unavailable or returns invalid data

**Example:**
```bash
HEIGHT=$(get_block_height)
if [ "$HEIGHT" != "unknown" ]; then
    echo "Current block height: $HEIGHT"
fi
```

### `get_titan_connection_status(username)`
Analyzes logs to determine Titan network connection status.

**Parameters:**
- `username`: Validator user account name

**Returns:**
- "connected" if last log entry shows connection
- "disconnected" if last log entry shows disconnection
- "unknown" if no connection logs found

**Example:**
```bash
STATUS=$(get_titan_connection_status "testnet-validator")
case "$STATUS" in
    "connected")
        echo "✓ Connected to Titan network"
        ;;
    "disconnected")
        echo "✗ Disconnected from Titan network"
        ;;
    *)
        echo "⚠ Titan connection status unknown"
        ;;
esac
```

### `get_recent_slot(username)`
Returns the most recent slot number from validator logs.

**Parameters:**
- `username`: Validator user account name

**Returns:**
- Slot number (numeric string) if found in logs
- "unknown" if no slot activity found

**Example:**
```bash
SLOT=$(get_recent_slot "testnet-validator")
if [ "$SLOT" != "unknown" ]; then
    echo "Recent slot activity: $SLOT"
fi
```

## Error Analysis Functions

### `get_error_count(username)`
Returns the total number of ERROR entries in validator logs.

**Parameters:**
- `username`: Validator user account name

**Returns:**
- Total error count (numeric string, "0" if no errors)

**Example:**
```bash
ERRORS=$(get_error_count "testnet-validator")
if [ "$ERRORS" -gt 0 ]; then
    echo "Total errors logged: $ERRORS"
fi
```

### `get_recent_error_count(username)`
Returns the number of ERROR entries in the last hour.

**Parameters:**
- `username`: Validator user account name

**Returns:**
- Recent error count (numeric string, "0" if no recent errors)
- "unknown" if time calculation fails

**Example:**
```bash
RECENT_ERRORS=$(get_recent_error_count "testnet-validator")
if [ "$RECENT_ERRORS" != "unknown" ] && [ "$RECENT_ERRORS" -gt 0 ]; then
    echo "Recent errors (last hour): $RECENT_ERRORS"
fi
```

### `get_last_error(username)`
Returns the most recent ERROR log entry.

**Parameters:**
- `username`: Validator user account name

**Returns:**
- Full text of last error log line
- Empty string if no errors found

**Example:**
```bash
LAST_ERROR=$(get_last_error "testnet-validator")
if [ -n "$LAST_ERROR" ]; then
    echo "Last error: $(echo "$LAST_ERROR" | cut -c1-80)..."
fi
```

## System Information Functions

### `get_restart_count(username)`
Returns the number of validator restart events found in logs.

**Parameters:**
- `username`: Validator user account name

**Returns:**
- Restart count (numeric string, "0" if no restarts detected)

**Example:**
```bash
RESTARTS=$(get_restart_count "testnet-validator")
if [ "$RESTARTS" -gt 1 ]; then
    echo "Validator has restarted $RESTARTS times"
fi
```

### `get_last_restart(username)`
Returns the timestamp of the most recent restart.

**Parameters:**
- `username`: Validator user account name

**Returns:**
- Timestamp string (e.g., "2025-01-15 14:30:25") of last restart
- "unknown" if no restart events found

**Example:**
```bash
LAST_RESTART=$(get_last_restart "testnet-validator")
if [ "$LAST_RESTART" != "unknown" ]; then
    echo "Last restart: $LAST_RESTART"
fi
```

### `get_data_sizes(username)`
Returns validator data directory sizes.

**Parameters:**
- `username`: Validator user account name

**Returns:**
- Pipe-separated string: "ledger_size|total_size" (e.g., "1.2G|2.4G")
- "N/A|N/A" if directories don't exist or are inaccessible

**Example:**
```bash
DATA_SIZES=$(get_data_sizes "testnet-validator")
LEDGER_SIZE=$(echo "$DATA_SIZES" | cut -d'|' -f1)
TOTAL_SIZE=$(echo "$DATA_SIZES" | cut -d'|' -f2)
echo "Ledger: $LEDGER_SIZE, Total: $TOTAL_SIZE"
```

### `get_recent_log_lines(username, [count])`
Returns the most recent log entries.

**Parameters:**
- `username`: Validator user account name
- `count`: Number of lines to return (optional, defaults to 2)

**Returns:**
- Recent log lines (newline-separated)
- Empty string if no logs available

**Example:**
```bash
RECENT_LOGS=$(get_recent_log_lines "testnet-validator" 5)
if [ -n "$RECENT_LOGS" ]; then
    echo "Recent activity:"
    echo "$RECENT_LOGS" | while read line; do
        echo "  $line"
    done
fi
```

## Infrastructure Functions

These functions are used internally by the infrastructure scripts and are generally not needed for monitoring or interactive use.

### `create_user(username)`
Creates a validator user account with proper home directory setup.

### `deploy_validator_operator(username)`
Deploys validator runtime scripts and configuration for a user.

### `clobber_validator_operator(username)`
Removes validator scripts and configuration for a user.

### `clobber_user(username)`
Completely removes a validator user account and all associated data.

## Error Handling

All utility functions follow consistent error handling patterns:

- **Silent failures**: Functions return "unknown", empty string, or "0" rather than failing
- **No stderr output**: Functions don't produce error messages to stderr
- **Consistent return values**: Predictable return formats for easy parsing
- **Safe defaults**: Functions handle missing files, users, or data gracefully

## Performance Considerations

- **Caching**: Functions don't cache results; each call performs fresh queries
- **Timeouts**: Network functions (RPC calls) have 3-second timeouts
- **Efficiency**: Log parsing functions use efficient grep/tail combinations
- **Resource usage**: Functions minimize system resource consumption

## Integration Examples

### Custom Health Check Function
```bash
source common.sh

validator_health_summary() {
    local user="$1"
    echo "=== Validator Health Summary ==="
    echo "Process: $(is_validator_running "$user" && echo "Running" || echo "Stopped")"
    echo "RPC: $(is_rpc_listening && echo "Listening" || echo "Down")"
    echo "Block Height: $(get_block_height)"
    echo "Network: $(get_titan_connection_status "$user")"
    echo "Errors: $(get_error_count "$user") total, $(get_recent_error_count "$user") recent"
    echo "Data Size: $(get_data_sizes "$user" | cut -d'|' -f2)"
}

# Usage
validator_health_summary "testnet-validator"
```

### Monitoring Loop
```bash
source common.sh
export VALIDATOR_USER=testnet-validator

while true; do
    if ! is_validator_running "$VALIDATOR_USER"; then
        echo "$(date): Validator stopped, checking logs..."
        get_recent_log_lines "$VALIDATOR_USER" 10
    fi
    sleep 30
done
```

### Alert Conditions
```bash
source common.sh

check_alert_conditions() {
    local user="$1"
    local alerts=0
    
    # Check if validator is running
    if ! is_validator_running "$user"; then
        echo "ALERT: Validator process stopped"
        ((alerts++))
    fi
    
    # Check RPC health
    if ! is_rpc_listening; then
        echo "ALERT: RPC server not responding"
        ((alerts++))
    fi
    
    # Check for recent errors
    local recent_errors=$(get_recent_error_count "$user")
    if [ "$recent_errors" != "unknown" ] && [ "$recent_errors" -gt 5 ]; then
        echo "ALERT: High error rate ($recent_errors errors in last hour)"
        ((alerts++))
    fi
    
    # Check network connectivity
    local titan_status=$(get_titan_connection_status "$user")
    if [ "$titan_status" = "disconnected" ]; then
        echo "ALERT: Disconnected from Titan network"
        ((alerts++))
    fi
    
    return $alerts
}

# Usage
if check_alert_conditions "testnet-validator"; then
    echo "All systems normal"
else
    echo "Alerts detected - check validator status"
fi
``` 