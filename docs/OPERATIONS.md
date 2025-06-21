# Validator Operations Guide

This guide covers day-to-day operational procedures for managing Arch Network validators using the valops toolkit.

## Quick Reference

```bash
# Essential commands for daily operations
./check-env                                   # Security assessment (run first)
./env-init                                    # Deploy/update environment
./sync-bins                                   # Sync latest binaries
sudo -u testnet-validator ./resources/run-validator    # Start validator
sudo -u testnet-validator ./resources/halt-validator   # Stop validator
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

# 2. Deploy validator environment (creates user, directories, scripts)
./env-init

# 3. Sync binaries from development VM
./sync-bins

# 4. Verify deployment
sudo -u testnet-validator ls -la /home/testnet-validator/
which arch-cli validator
```

### Environment Updates

```bash
# Update deployed scripts (after modifying resources/)
./env-init  # Always safe to run - uses deploy semantics

# Update binaries (after rebuilding in dev-env)
./sync-bins  # Only transfers if binaries changed

# Verify updates
ls -la /usr/local/bin/{arch-cli,validator}
sudo -u testnet-validator ls -la /home/testnet-validator/{run-validator,halt-validator}
```

### Environment Cleanup

```bash
# Remove validator operator (keeps user account)
source common.sh
clobber_validator_operator "testnet-validator"

# Complete removal (deletes user and all data)
source common.sh
clobber_user "testnet-validator"
```

## Validator Lifecycle Management

### Starting the Validator

**Standard Startup:**
```bash
# Start validator (runs in foreground with full logging)
sudo -u testnet-validator /home/testnet-validator/run-validator
```

**Background Startup:**
```bash
# Start validator in background
sudo -u testnet-validator nohup /home/testnet-validator/run-validator > /dev/null 2>&1 &

# Or use screen/tmux for persistent sessions
sudo -u testnet-validator screen -dmS validator /home/testnet-validator/run-validator
```

**Startup Verification:**
```bash
# Check process status
source common.sh
export VALIDATOR_USER=testnet-validator
is_validator_running "$VALIDATOR_USER" && echo "Running" || echo "Stopped"

# Get process details
PID=$(get_validator_pid "$VALIDATOR_USER")
echo "Validator PID: $PID"

# Check RPC endpoint
curl -X POST -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"get_block_count","params":[],"id":1}' \
  http://127.0.0.1:9002/
```

### Stopping the Validator

**Graceful Shutdown:**
```bash
# Recommended method (handles multiple processes, timeouts, fallbacks)
sudo -u testnet-validator /home/testnet-validator/halt-validator
```

**Manual Shutdown:**
```bash
# Find validator processes
sudo -u testnet-validator pgrep -f arch-cli

# Graceful termination
sudo -u testnet-validator pkill -TERM -f arch-cli

# Force termination (if needed)
sudo -u testnet-validator pkill -KILL -f arch-cli
```

**Shutdown Verification:**
```bash
# Verify all processes stopped
sudo -u testnet-validator pgrep -f arch-cli || echo "All stopped"

# Check RPC endpoint is down
curl -X POST -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"get_block_count","params":[],"id":1}' \
  http://127.0.0.1:9002/ || echo "RPC not responding"
```

### Restart Procedures

**Standard Restart:**
```bash
# Stop validator
sudo -u testnet-validator /home/testnet-validator/halt-validator

# Wait for complete shutdown
sleep 5

# Start validator
sudo -u testnet-validator /home/testnet-validator/run-validator
```

**Quick Restart (for configuration changes):**
```bash
# Combined restart script
sudo -u testnet-validator bash -c "
  /home/testnet-validator/halt-validator
  sleep 3
  /home/testnet-validator/run-validator
"
```

**Emergency Restart (if validator is unresponsive):**
```bash
# Nuclear option - force kill all validator processes
sudo pkill -KILL -f "arch-cli.*validator"
sleep 2
sudo -u testnet-validator /home/testnet-validator/run-validator
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
grep -E "run-validator:|halt-validator:" /home/testnet-validator/logs/validator.log* | tail -10

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
source common.sh
export VALIDATOR_USER=testnet-validator

# Check processing performance
echo "Block height: $(get_block_height)"
echo "Recent slot: $(get_recent_slot "$VALIDATOR_USER")"
echo "Error rate: $(get_recent_error_count "$VALIDATOR_USER") per hour"
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
# Verify no private keys in validator directories
sudo -u testnet-validator find /home/testnet-validator/ -name "*.key" -o -name "*.pem"

# Check for any credential files
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
source common.sh
export VALIDATOR_USER=testnet-validator
./validator-dashboard-helpers/status-check

# Verify key metrics
echo "Process: $(is_validator_running "$VALIDATOR_USER" && echo "✓" || echo "✗")"
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
sudo -u testnet-validator /home/testnet-validator/halt-validator
sudo -u testnet-validator /home/testnet-validator/run-validator
```

**Performance Review:**
```bash
# Check data growth
du -sh /home/testnet-validator/data/.arch_data/testnet/ledger

# Review error trends
grep ERROR /home/testnet-validator/logs/validator.log* | wc -l

# Check restart frequency
grep -E "run-validator:|halt-validator:" /home/testnet-validator/logs/validator.log* | wc -l
```

### Monthly Maintenance

**Deep Health Check:**
```bash
# Comprehensive system check
df -h  # Disk space
free -h  # Memory usage
uptime  # System load

# Validator-specific checks
source common.sh
export VALIDATOR_USER=testnet-validator
echo "Restarts: $(get_restart_count "$VALIDATOR_USER")"
echo "Total errors: $(get_error_count "$VALIDATOR_USER")"
echo "Data size: $(get_data_sizes "$VALIDATOR_USER")"
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
cp common.sh env-init sync-bins validator-dashboard "$BACKUP_DIR/"

# Copy validator-specific configuration
sudo cp -r /home/testnet-validator/{run-validator,halt-validator} "$BACKUP_DIR/" 2>/dev/null || true
sudo cp /etc/logrotate.d/validator-testnet-validator "$BACKUP_DIR/" 2>/dev/null || true

# Create recovery documentation
cat << 'EOF' > "$BACKUP_DIR/RECOVERY.md"
# Validator Recovery Procedure

1. Deploy environment: ./env-init
2. Sync binaries: ./sync-bins
3. Start validator: sudo -u testnet-validator ./run-validator
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

# 2. Deploy environment
./env-init

# 3. Sync binaries
./sync-bins

# 4. Start validator
sudo -u testnet-validator /home/testnet-validator/run-validator

# 5. Verify operation
VALIDATOR_USER=testnet-validator ./validator-dashboard-helpers/status-check
```

**Partial Recovery (Configuration Only):**
```bash
# Redeploy scripts and configuration
./env-init

# Restart validator with new configuration
sudo -u testnet-validator /home/testnet-validator/halt-validator
sudo -u testnet-validator /home/testnet-validator/run-validator
```

## Troubleshooting Common Issues

### Validator Won't Start

**Symptoms:** Process starts but immediately exits
```bash
# Check recent startup logs
grep "run-validator:" /home/testnet-validator/logs/validator.log | tail -5

# Check for permission issues
sudo -u testnet-validator ls -la /home/testnet-validator/data/

# Verify binary integrity
which arch-cli validator
arch-cli --version 2>/dev/null || echo "Binary issue"
```

**Solutions:**
1. Verify environment setup: `./env-init`
2. Check binary installation: `./sync-bins`
3. Review configuration: Check environment variables
4. Check disk space: `df -h`

### High Resource Usage

**Symptoms:** High CPU/memory usage, slow system response
```bash
# Monitor resource usage
htop -u testnet-validator
sudo iotop -u testnet-validator

# Check for multiple processes
source common.sh
export VALIDATOR_USER=testnet-validator
echo "Process count: $(get_validator_pid_count "$VALIDATOR_USER")"
```

**Solutions:**
1. Check for multiple validator processes
2. Review system resources and other processes
3. Consider hardware upgrades
4. Optimize validator configuration

### Network Connectivity Issues

**Symptoms:** RPC timeouts, Titan disconnections
```bash
# Test network connectivity
curl -s https://titan-public-http.test.arch.network | head -5
nc -zv titan-public-tcp.test.arch.network 3030

# Check local RPC
curl -X POST -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"get_block_count","params":[],"id":1}' \
  http://127.0.0.1:9002/
```

**Solutions:**
1. Check firewall settings
2. Verify network configuration
3. Test with different endpoints
4. Review validator logs for network errors

This operations guide provides comprehensive procedures for managing your Arch Network validator efficiently and securely. 