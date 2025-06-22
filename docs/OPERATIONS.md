# Validator Operations Guide

This guide covers day-to-day operational procedures for managing Arch Network validators using the valops toolkit.

## Quick Reference

```bash
# Essential commands for daily operations
./check-env                                   # Security assessment (run first)
./setup-age-keys                              # Setup encryption keys (one-time)
./validator-init --encrypted-identity-key validator-identity.age --network testnet --user testnet-validator  # Initialize (one-time)
./validator-up --user testnet-validator      # Start validator
./validator-down --user testnet-validator    # Stop validator
VALIDATOR_USER=testnet-validator ./validator-dashboard # Monitor
```

## Security Assessment

Before deploying or operating validators, assess the host security posture:

```bash
# Run comprehensive security assessment
./check-env
```

This tool evaluates SSH security, firewall configuration, intrusion prevention, system updates, user security, network security, system hardening, and file system security. Address any critical issues before proceeding with validator deployment.

**Key Security Checks:**
- SSH configuration and effective settings
- Firewall rules and port exposure
- Intrusion prevention (fail2ban) status
- System update currency and automation
- User privilege isolation
- Network service exposure
- Kernel security hardening
- File system permissions

## Environment Management

### Initial Deployment

```bash
# 1. Assess host security (recommended first step)
./check-env

# 2. Setup age encryption keys (one-time)
./setup-age-keys

# 3. Sync binaries from development VM
./sync-bins

# 4. Initialize validator with encrypted identity (one-time)
./validator-init --encrypted-identity-key validator-identity.age --network testnet --user testnet-validator

# 5. Verify deployment
sudo -u testnet-validator ls -la /home/testnet-validator/
which validator
```

### Environment Updates

```bash
# Update deployed scripts and configuration (automatic during startup)
./validator-down --user testnet-validator
./validator-up --user testnet-validator  # Updates scripts automatically

# Update binaries (after rebuilding in dev-env)
./sync-bins  # Only transfers if binaries changed
./validator-down --user testnet-validator
./validator-up --user testnet-validator  # Restart with new binaries

# Verify updates
ls -la /usr/local/bin/validator
sudo -u testnet-validator ls -la /home/testnet-validator/{run-validator,halt-validator}
```

### Environment Cleanup

```bash
# Stop validator only
./validator-down --user testnet-validator

# Complete removal (deletes user and all data)
./validator-down --clobber --user testnet-validator
```

## Validator Lifecycle Management

### Starting the Validator

**Standard Startup:**
```bash
# Start validator (updates configuration and starts process)
./validator-up --user testnet-validator
```

**What this does:**
- Updates validator scripts to latest versions
- Refreshes log rotation and firewall configuration
- Starts the validator process in the background

**Startup Verification:**
```bash
# Check process status
source lib.sh
is_validator_running "testnet-validator" && echo "Running" || echo "Stopped"

# Get process details
PID=$(get_validator_pid "testnet-validator")
echo "Validator PID: $PID"

# Check RPC endpoint
curl -X POST -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"get_block_count","params":[],"id":1}' \
  http://127.0.0.1:9002/
```

### Stopping the Validator

**Graceful Shutdown:**
```bash
# Recommended method (uses halt-validator script with timeouts and fallbacks)
./validator-down --user testnet-validator
```

**Manual Shutdown (if needed):**
```bash
# Direct halt-validator call
sudo su - testnet-validator -c "./halt-validator"

# Manual process termination
sudo su - testnet-validator -c "pkill -TERM -f '^validator --network-mode'"
```

**Shutdown Verification:**
```bash
# Verify all processes stopped
source lib.sh
is_validator_running "testnet-validator" || echo "All stopped"

# Check RPC endpoint is down
curl -X POST -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"get_block_count","params":[],"id":1}' \
  http://127.0.0.1:9002/ || echo "RPC not responding"
```

### Restart Procedures

**Standard Restart:**
```bash
# Stop and start
./validator-down --user testnet-validator
./validator-up --user testnet-validator
```

**Quick Status Check:**
```bash
# Check if restart is needed
source lib.sh
if is_validator_running "testnet-validator"; then
    echo "Validator is running"
else
    echo "Validator needs to be started"
    ./validator-up --user testnet-validator
fi
```

## Configuration Management

### Environment Variables

The validator runtime is configured through environment variables with sensible defaults:

```bash
# View current configuration
sudo -u testnet-validator cat << 'EOF'
# Default validator configuration
ARCH_DATA_DIR=${ARCH_DATA_DIR:-$HOME/data/.arch_data}
ARCH_RPC_BIND_IP=${ARCH_RPC_BIND_IP:-127.0.0.1}
ARCH_RPC_BIND_PORT=${ARCH_RPC_BIND_PORT:-9002}
ARCH_TITAN_ENDPOINT=${ARCH_TITAN_ENDPOINT:-https://titan-public-http.test.arch.network}
ARCH_TITAN_SOCKET_ENDPOINT=${ARCH_TITAN_SOCKET_ENDPOINT:-titan-public-tcp.test.arch.network:3030}
ARCH_NETWORK_MODE=${ARCH_NETWORK_MODE:-testnet}
EOF
```

### Custom Configuration

Create environment-specific configuration:

```bash
# Create custom environment file
sudo -u testnet-validator cat << 'EOF' > /home/testnet-validator/.validator-env
# Custom validator configuration
export ARCH_RPC_BIND_PORT=9003
export ARCH_TITAN_ENDPOINT=https://custom-endpoint.example.com
EOF

# Modify run-validator to source custom config
sudo -u testnet-validator sed -i '1a source ~/.validator-env 2>/dev/null || true' \
  /home/testnet-validator/run-validator
```

### Network Configuration

**Testnet (Default):**
```bash
export ARCH_NETWORK_MODE=testnet
export ARCH_TITAN_ENDPOINT=https://titan-public-http.test.arch.network
export ARCH_TITAN_SOCKET_ENDPOINT=titan-public-tcp.test.arch.network:3030
```

**Mainnet (When Available):**
```bash
export ARCH_NETWORK_MODE=mainnet
export ARCH_TITAN_ENDPOINT=https://titan-public-http.arch.network
export ARCH_TITAN_SOCKET_ENDPOINT=titan-public-tcp.arch.network:3030
```

## Log Management

### Log Locations

```bash
# Primary validator log
/home/testnet-validator/logs/validator.log

# Rotated logs (7-day retention)
/home/testnet-validator/logs/validator.log.1
/home/testnet-validator/logs/validator.log.2.gz
# ... up to validator.log.7.gz
```

### Log Analysis

**Real-time Monitoring:**
```bash
# Follow live logs
sudo -u testnet-validator tail -f /home/testnet-validator/logs/validator.log

# Follow with filtering
sudo -u testnet-validator tail -f /home/testnet-validator/logs/validator.log | grep -E "(ERROR|WARN|slot)"
```

**Historical Analysis:**
```bash
# Search for errors
grep ERROR /home/testnet-validator/logs/validator.log* | tail -20

# Network connectivity events
grep -i titan /home/testnet-validator/logs/validator.log* | tail -10

# Startup/shutdown events
grep -E "validator-up:|validator-down:" /home/testnet-validator/logs/validator.log* | tail -10

# Slot processing activity
grep "slot [0-9]*" /home/testnet-validator/logs/validator.log | tail -20
```

**Log Rotation Management:**
```bash
# Check rotation configuration
cat /etc/logrotate.d/validator-testnet-validator

# Test rotation (dry run)
sudo logrotate -d /etc/logrotate.d/validator-testnet-validator

# Force rotation
sudo logrotate -f /etc/logrotate.d/validator-testnet-validator

# Check rotation status
ls -la /home/testnet-validator/logs/
```

### Log Troubleshooting

**Log Growth Issues:**
```bash
# Monitor log size
watch -n 5 "du -sh /home/testnet-validator/logs/"

# Check for excessive logging
tail -100 /home/testnet-validator/logs/validator.log | cut -d' ' -f3- | sort | uniq -c | sort -nr

# Temporarily reduce log verbosity (if supported)
# This depends on validator binary capabilities
```

**Missing Logs:**
```bash
# Check log directory permissions
ls -la /home/testnet-validator/logs/

# Verify logrotate configuration
sudo logrotate -d /etc/logrotate.d/validator-testnet-validator

# Check if validator is writing to logs
sudo -u testnet-validator lsof +D /home/testnet-validator/logs/
```

## Data Management

### Data Directory Structure

```bash
# View data directory layout
sudo -u testnet-validator find /home/testnet-validator/data/ -type d | head -20

# Check data sizes
sudo -u testnet-validator du -sh /home/testnet-validator/data/.arch_data/testnet/*
```

### Backup Procedures

**Configuration Backup:**
```bash
# Backup validator configuration and logs
sudo tar -czf validator-backup-$(date +%Y%m%d).tar.gz \
  -C /home/testnet-validator \
  logs/ \
  run-validator \
  halt-validator \
  .validator-env 2>/dev/null || true
```

**Data Backup (Caution - Large Files):**
```bash
# Backup critical data (can be very large)
sudo -u testnet-validator tar -czf validator-data-$(date +%Y%m%d).tar.gz \
  -C /home/testnet-validator/data \
  .arch_data/testnet/
```

### Data Cleanup

**Log Cleanup:**
```bash
# Clean old rotated logs manually
sudo -u testnet-validator find /home/testnet-validator/logs/ -name "*.gz" -mtime +7 -delete

# Clean large log files (emergency)
sudo -u testnet-validator truncate -s 0 /home/testnet-validator/logs/validator.log
```

**Data Directory Cleanup:**
```bash
# Check for temporary files
sudo -u testnet-validator find /home/testnet-validator/data/ -name "*.tmp" -o -name "*.lock"

# Clean temporary files (be cautious)
sudo -u testnet-validator find /home/testnet-validator/data/ -name "*.tmp" -mtime +1 -delete
```

## Performance Optimization

### System Resources

**Monitor Resource Usage:**
```bash
# CPU and memory usage
htop -u testnet-validator

# Disk I/O
sudo iotop -u testnet-validator

# Network usage
sudo nethogs -u testnet-validator
```

**Optimize System Settings:**
```bash
# Increase file descriptor limits
echo "testnet-validator soft nofile 65536" | sudo tee -a /etc/security/limits.conf
echo "testnet-validator hard nofile 65536" | sudo tee -a /etc/security/limits.conf

# Optimize network settings (if needed)
echo "net.core.rmem_max = 134217728" | sudo tee -a /etc/sysctl.conf
echo "net.core.wmem_max = 134217728" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
```

### Validator Performance

**Monitor Validator Metrics:**
```bash
source lib.sh

# Check processing performance
echo "Block height: $(get_block_height)"
echo "Recent slot: $(get_recent_slot "testnet-validator")"
echo "Error rate: $(get_recent_error_count "testnet-validator") per hour"
```

**Performance Tuning:**
```bash
# Adjust RPC settings for better performance
export ARCH_RPC_BIND_IP=0.0.0.0  # Allow external connections (security consideration)
export ARCH_RPC_BIND_PORT=9002   # Standard port

# Optimize data directory location (use fast SSD)
export ARCH_DATA_DIR=/fast-ssd/validator-data/.arch_data
```

## Security Operations

### Access Control

**User Permissions:**
```bash
# Verify validator user permissions
id testnet-validator
sudo -u testnet-validator whoami

# Check home directory permissions
ls -la /home/testnet-validator/

# Verify sudo restrictions
sudo -l -U testnet-validator
```

**Network Security:**
```bash
# Check open ports
sudo ss -tlnp | grep -E "(9002|3030)"

# Verify firewall settings
sudo ufw status
sudo iptables -L | grep -E "(9002|3030)"
```

### Key Management

**Important:** Validator signing keys are managed separately from this infrastructure. The valops toolkit never handles cryptocurrency keys.

```bash
# Verify identity files are properly secured
sudo -u testnet-validator find /home/testnet-validator/ -name "identity-secret" -exec ls -la {} \;

# Check for any unexpected credential files
sudo -u testnet-validator find /home/testnet-validator/ -name "*secret*" -o -name "*private*"
```

### Security Monitoring

**Process Monitoring:**
```bash
# Monitor validator process integrity
ps aux | grep testnet-validator

# Check for unexpected processes
sudo -u testnet-validator ps -u testnet-validator
```

**Network Monitoring:**
```bash
# Monitor network connections
sudo ss -tulnp | grep testnet-validator

# Check for unexpected connections
sudo netstat -tulnp | grep -E "(9002|3030)"
```

## Maintenance Procedures

### Daily Maintenance

**Health Check (2 minutes):**
```bash
# Quick status check
source lib.sh
./validator-dashboard-helpers/status-check

# Verify key metrics
echo "Process: $(is_validator_running "testnet-validator" && echo "✓" || echo "✗")"
echo "RPC: $(is_rpc_listening && echo "✓" || echo "✗")"
echo "Block: $(get_block_height)"
```

**Log Review (3 minutes):**
```bash
# Check for recent errors
grep ERROR /home/testnet-validator/logs/validator.log | tail -5

# Verify normal activity
tail -10 /home/testnet-validator/logs/validator.log
```

### Weekly Maintenance

**System Updates:**
```bash
# Update system packages
sudo apt update && sudo apt upgrade -y

# Update validator binaries (if needed)
# 1. Build new binaries in dev-env VM
# 2. Sync to bare metal
./sync-bins

# 3. Restart validator if binaries changed
./validator-down --user testnet-validator
./validator-up --user testnet-validator
```

**Performance Review:**
```bash
# Check data growth
du -sh /home/testnet-validator/data/.arch_data/testnet/ledger

# Review error trends
grep ERROR /home/testnet-validator/logs/validator.log* | wc -l

# Check restart frequency
source lib.sh
echo "Restarts: $(get_restart_count "testnet-validator")"
```

### Monthly Maintenance

**Deep Health Check:**
```bash
# Comprehensive system check
df -h  # Disk space
free -h  # Memory usage
uptime  # System load

# Validator-specific checks
source lib.sh
echo "Restarts: $(get_restart_count "testnet-validator")"
echo "Total errors: $(get_error_count "testnet-validator")"
echo "Data size: $(get_data_sizes "testnet-validator")"
```

**Configuration Review:**
```bash
# Review validator configuration
sudo -u testnet-validator env | grep ARCH_

# Check log rotation
ls -la /home/testnet-validator/logs/

# Verify backups (if implemented)
ls -la validator-backup-*.tar.gz
```

## Disaster Recovery

### Backup Procedures

**Create Recovery Package:**
```bash
#!/bin/bash
# Create complete recovery package
DATE=$(date +%Y%m%d-%H%M%S)
BACKUP_DIR="validator-recovery-$DATE"

mkdir -p "$BACKUP_DIR"

# Copy configuration and scripts
cp -r resources/ "$BACKUP_DIR/"
cp lib.sh setup-age-keys validator-init validator-up validator-down sync-bins validator-dashboard "$BACKUP_DIR/"

# Copy validator-specific configuration
sudo cp -r /home/testnet-validator/{run-validator,halt-validator} "$BACKUP_DIR/" 2>/dev/null || true
sudo cp /etc/logrotate.d/validator-testnet-validator "$BACKUP_DIR/" 2>/dev/null || true

# Create recovery documentation
cat << 'EOF' > "$BACKUP_DIR/RECOVERY.md"
# Validator Recovery Procedure

1. Setup age keys: ./setup-age-keys
2. Initialize validator: ./validator-init --encrypted-identity-key validator-identity.age --network testnet --user testnet-validator
3. Start validator: ./validator-up --user testnet-validator
4. Monitor: VALIDATOR_USER=testnet-validator ./validator-dashboard
EOF

tar -czf "$BACKUP_DIR.tar.gz" "$BACKUP_DIR"
rm -rf "$BACKUP_DIR"
echo "Recovery package created: $BACKUP_DIR.tar.gz"
```

### Recovery Procedures

**Complete System Recovery:**
```bash
# 1. Extract recovery package
tar -xzf validator-recovery-*.tar.gz
cd validator-recovery-*/

# 2. Setup age keys (if not already done)
./setup-age-keys

# 3. Initialize validator
./validator-init --encrypted-identity-key validator-identity.age --network testnet --user testnet-validator

# 4. Start validator
./validator-up --user testnet-validator

# 5. Verify operation
./validator-dashboard-helpers/status-check
```

**Partial Recovery (Configuration Only):**
```bash
# Restart validator to refresh configuration
./validator-down --user testnet-validator
./validator-up --user testnet-validator
```

## Troubleshooting Common Issues

### Validator Won't Start

**Symptoms:** `validator-up` fails or process starts but immediately exits
```bash
# Check initialization status
sudo -u testnet-validator ls -la /home/testnet-validator/

# Check recent startup logs
grep "validator-up:" /home/testnet-validator/logs/validator.log | tail -5

# Verify binary integrity
which validator
validator --version 2>/dev/null || echo "Binary issue"
```

**Solutions:**
1. Verify initialization: `./validator-init --encrypted-identity-key validator-identity.age --network testnet --user testnet-validator`
2. Check binary installation: `./sync-bins`
3. Review configuration: Check environment variables
4. Check disk space: `df -h`

### High Resource Usage

**Symptoms:** High CPU, memory, or disk usage
```bash
# Monitor resource usage
source lib.sh
htop -u testnet-validator

# Check validator metrics
echo "Process count: $(get_validator_pid_count "testnet-validator")"
echo "Data size: $(get_data_sizes "testnet-validator")"
```

**Solutions:**
1. Check for multiple processes: Only one validator should be running
2. Review log growth: Large logs can consume significant resources
3. Monitor data directory growth: Consider cleanup procedures
4. Optimize system settings: Adjust file descriptors and network settings

### Network Connectivity Issues

**Symptoms:** RPC not responding, network connection errors
```bash
# Check network status
source lib.sh
is_rpc_listening && echo "RPC OK" || echo "RPC DOWN"
echo "Titan status: $(get_titan_connection_status "testnet-validator")"

# Check firewall
sudo ufw status
```

**Solutions:**
1. Verify firewall configuration: `./validator-up` refreshes firewall rules
2. Check network endpoints: Verify titan endpoints are reachable
3. Review RPC binding: Ensure correct IP and port configuration
4. Restart validator: `./validator-down --user testnet-validator && ./validator-up --user testnet-validator`

### Identity/Authentication Issues

**Symptoms:** Identity deployment failures, peer ID mismatches
```bash
# Check identity files
sudo -u testnet-validator find /home/testnet-validator/data/.arch_data/ -name "identity-secret"

# Verify age keys
ls -la ~/.valops/age/
```

**Solutions:**
1. Verify age keys: `./setup-age-keys`
2. Re-initialize if needed: `./validator-down --clobber --user testnet-validator` then re-init
3. Check encrypted identity file integrity
4. Verify correct public key was used for encryption

## Interactive Operations

### Using lib.sh Functions

```bash
# Source the library for interactive use
source lib.sh

# Check validator status
is_validator_running "testnet-validator" && echo "Running" || echo "Stopped"

# Get process information
get_validator_pid "testnet-validator"
get_validator_uptime "testnet-validator" "$(get_validator_pid "testnet-validator")"

# Stop validator manually
stop_validator "testnet-validator"

# Security operations
shred_validator_identities "testnet-validator"  # Secure cleanup
```

### Advanced Operations

```bash
# Multiple validator management
for user in testnet-validator mainnet-validator; do
    if is_validator_running "$user"; then
        echo "$user: Running (PID: $(get_validator_pid "$user"))"
    else
        echo "$user: Stopped"
    fi
done

# Bulk operations
source lib.sh
./validator-down --user testnet-validator
./validator-up --user testnet-validator
```

This comprehensive operations guide provides everything needed for day-to-day validator management using the new architecture while maintaining the same level of operational excellence. 