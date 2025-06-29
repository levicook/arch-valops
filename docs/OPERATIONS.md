# Operations Guide

👔 **For**: Production operators managing Arch Network validators
🎯 **Focus**: Daily management, maintenance, troubleshooting

## Quick Reference

```bash
# Daily operations (with pre-configured environment)
cd validators/testnet && validator-dashboard  # Monitor validator
validator-up                          # Start validator
validator-down                        # Stop validator
validator-down --clobber              # Complete removal (with backup)

# Or using environment variables
VALIDATOR_USER=testnet-validator validator-dashboard
VALIDATOR_USER=testnet-validator validator-up
VALIDATOR_USER=testnet-validator validator-down

# Binary updates
ARCH_VERSION=v0.5.3 sync-arch-bins    # Update Arch binaries
BITCOIN_VERSION=29.0 sync-bitcoin-bins # Update Bitcoin binaries
sync-titan-bins                       # Update Titan binary

# Health checks
tail -f /home/$VALIDATOR_USER/logs/validator.log  # Live logs (set VALIDATOR_USER first)
curl -X POST -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"get_block_count","params":[],"id":1}' http://127.0.0.1:9002/  # Test RPC
```

## Validator Lifecycle

### Starting
```bash
# Standard startup (updates configs, starts process)
validator-up

# Verify startup
validator-dashboard  # Check status window
```

### Stopping
```bash
# Graceful shutdown
validator-down

# Force stop if needed
sudo pkill -f validator
```

### Restarting
```bash
# Standard restart
validator-down && validator-up

# Emergency restart (manual process management - no systemd)
sudo pkill -f validator && validator-up  # Force restart
```

## Binary Management

### Production Updates
```bash
# Update to specific versions (recommended)
ARCH_VERSION=v0.5.3 sync-arch-bins
BITCOIN_VERSION=29.0 sync-bitcoin-bins

# Restart to use new binaries
validator-down && validator-up
```

### Development Updates
```bash
# Sync from development VM
SYNC_STRATEGY_ARCH=vm sync-arch-bins
SYNC_STRATEGY_BITCOIN=vm sync-bitcoin-bins
sync-titan-bins

# Restart validator
validator-down && validator-up
```

**See [MANAGEMENT.md](MANAGEMENT.md) for complete binary management guide.**

## Monitoring

### Dashboard
```bash
# Start monitoring dashboard
validator-dashboard

# Navigation
# Ctrl+b + n/p  - Switch windows
# Ctrl+b + d    - Detach (keeps running)
# Ctrl+b + arrows - Switch panes
```

### Manual Health Checks
```bash
# Process status
ps aux | grep validator

# RPC health
curl -X POST -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"get_block_count","params":[],"id":1}' http://127.0.0.1:9002/

# Log analysis
tail -20 /home/testnet-validator/logs/validator.log
grep ERROR /home/testnet-validator/logs/validator.log | tail -10
```

### Key Metrics to Monitor
- **Process**: Validator running, single instance
- **RPC**: Port 9002 responding
- **Network**: Connected to Titan endpoints
- **Disk**: Data directory growth
- **Logs**: No recurring errors

**See [OBSERVABILITY.md](OBSERVABILITY.md) for comprehensive monitoring setup.**

## Maintenance Tasks

### Daily
- Check dashboard for errors
- Verify RPC connectivity
- Monitor log for unusual activity

### Weekly
```bash
# System updates
sudo apt update && sudo apt upgrade -y

# Log cleanup (automatic via logrotate)
ls -la /home/testnet-validator/logs/

# Disk usage check
df -h
du -sh /home/testnet-validator/data/
```

### Monthly
```bash
# Review validator performance
grep "block height" /home/testnet-validator/logs/validator.log | tail -20

# Check for restarts
grep "validator-up" /home/testnet-validator/logs/validator.log | wc -l

# Binary updates (as needed)
# Check for new releases and update per Binary Management section
```

## Troubleshooting

### Validator Won't Start
**Symptoms**: `validator-up` fails or process exits immediately

**Diagnosis**:
```bash
# Check recent logs
tail -50 /home/testnet-validator/logs/validator.log

# Verify binary
which validator && validator --version

# Check user/permissions
sudo -u testnet-validator ls -la /home/testnet-validator/
```

**Solutions**:
1. **Re-initialize**: `VALIDATOR_ENCRYPTED_IDENTITY_KEY=backup.age validator-init`
2. **Update binaries**: See Binary Management section
3. **Check disk space**: `df -h`
4. **Review config**: Environment variables in `validators/testnet/.envrc`

### High Resource Usage
**Symptoms**: High CPU/memory/disk usage

**Diagnosis**:
```bash
# Check processes
htop -u testnet-validator

# Check disk usage
du -sh /home/testnet-validator/data/*

# Check for multiple processes
ps aux | grep validator | wc -l
```

**Solutions**:
1. **Multiple processes**: Kill extras, ensure only one running
2. **Disk space**: Monitor data directory growth, consider cleanup
3. **Memory leaks**: Restart validator: `validator-down && validator-up`

### Network Connectivity Issues
**Symptoms**: RPC not responding, Titan connection errors

**Diagnosis**:
```bash
# Check port binding
sudo ss -tlnp | grep 9002

# Test endpoints
curl -s https://titan-public-http.test.arch.network | head -5
nc -zv titan-public-tcp.test.arch.network 3030

# Check firewall
sudo ufw status
```

**Solutions**:
1. **Firewall**: `validator-up` refreshes firewall rules
2. **Port conflicts**: Check if port 9002 is used by other services
3. **Network**: Verify internet connectivity and DNS resolution
4. **Restart**: `validator-down && validator-up`

### Identity/Backup Issues
**Symptoms**: Identity deployment failures, backup errors

**Diagnosis**:
```bash
# Check identity files
sudo -u testnet-validator find /home/testnet-validator/data/ -name "*identity*"

# Check backups
ls -la ~/.valops/age/identity-backup-*

# Verify age keys
ls -la ~/.valops/age/
```

**Solutions**:
1. **Restore from backup**: `VALIDATOR_ENCRYPTED_IDENTITY_KEY=~/.valops/age/identity-backup-{peer-id}.age validator-init`
2. **Re-generate identity**: See [IDENTITY-GENERATION.md](IDENTITY-GENERATION.md)
3. **Age key issues**: `setup-age-keys` to recreate

## Emergency Procedures

### Complete Validator Removal
```bash
# WARNING: Creates automatic backup before destruction
validator-down --clobber

# This will:
# 1. Backup all identities to ~/.valops/age/
# 2. Stop validator process
# 3. Remove user and all data
# 4. Show 3-second abort window
```

### Disaster Recovery
```bash
# Restore from backup
VALIDATOR_ENCRYPTED_IDENTITY_KEY=~/.valops/age/identity-backup-{peer-id}.age validator-init

# Restart operations
validator-up && validator-dashboard
```

### Emergency Contacts
- **Logs**: `/home/testnet-validator/logs/validator.log`
- **Configs**: `validators/testnet/.envrc`
- **Backups**: `~/.valops/age/identity-backup-*`
- **Full troubleshooting**: See legacy docs in `docs/legacy/` for detailed debugging

---

**Quick actions** → This guide | **Initial setup** → [QUICK-START.md](QUICK-START.md) | **Security review** → [SECURITY.md](SECURITY.md) | **Advanced monitoring** → [OBSERVABILITY.md](OBSERVABILITY.md)