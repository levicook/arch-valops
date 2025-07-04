# Operations Guide

👔 **For**: Production operators managing Arch Network validator infrastructure
🎯 **Focus**: Daily management, service operations, troubleshooting

## Quick Reference

```bash
# Infrastructure service management (dependency order: Bitcoin → Titan → Validator)
cd validators/testnet

# Service control
bitcoin-up / bitcoin-down      # Bitcoin testnet4 node
titan-up / titan-down          # Titan rune indexer
validator-up / validator-down   # Arch validator

# Service status
bitcoin-status                 # Bitcoin sync and network status
titan-status                   # Titan indexing progress
validator-dashboard            # Validator monitoring dashboard

# Complete teardown (with automatic backups)
validator-down --clobber      # Removes validator user and data
titan-down --clobber          # Removes titan user and data
bitcoin-down --clobber        # Removes bitcoin user and data

# Binary updates
sync-arch-bins                # Update Arch binaries
sync-bitcoin-bins             # Update Bitcoin binaries
sync-titan-bins               # Update Titan binaries
```

## Service Architecture

Your validator runs a complete infrastructure stack:

```
Bitcoin testnet4 node (testnet-bitcoin user)
├── Port: 48332 (RPC)
├── Port: 48333 (P2P)
├── Data: /home/testnet-bitcoin/data
└── Logs: journalctl -u arch-bitcoind@testnet-bitcoin
    ↓
Titan rune indexer (testnet-titan user)
├── Port: 3030 (HTTP API)
├── Data: /home/testnet-titan/data
├── Logs: journalctl -u arch-titan@testnet-titan
└── Depends on: Bitcoin RPC
    ↓
Arch validator (testnet-validator user)
├── Port: 9002 (RPC)
├── Port: 8081 (WebSocket, if enabled)
├── Data: /home/testnet-validator/data
├── Logs: journalctl -u arch-validator@testnet-validator
└── Depends on: Titan HTTP API
```

## Service Operations

### Bitcoin Node
```bash
# Start/stop Bitcoin node
bitcoin-up                    # Starts Bitcoin testnet4 node
bitcoin-down                  # Stops Bitcoin node gracefully

# Monitor Bitcoin
bitcoin-status               # Comprehensive Bitcoin status
journalctl -u arch-bitcoind@testnet-bitcoin -f  # Live logs

# Bitcoin takes 20-30 minutes to sync testnet4 from network
```

### Titan Indexer
```bash
# Start/stop Titan (requires Bitcoin to be running)
titan-up                     # Starts Titan rune indexer
titan-down                   # Stops Titan gracefully

# Monitor Titan
titan-status                 # Comprehensive Titan status
journalctl -u arch-titan@testnet-titan -f       # Live logs

# Titan syncs from Bitcoin - check titan-status for progress
```

### Validator
```bash
# Start/stop Validator (requires Bitcoin + Titan running)
validator-up                 # Starts Arch validator
validator-down               # Stops validator gracefully

# Monitor Validator
validator-dashboard          # Interactive monitoring dashboard
journalctl -u arch-validator@testnet-validator -f  # Live logs

# Dashboard navigation: Ctrl+b + n/p (windows), Ctrl+b + d (detach)
```

## Service Dependencies

**Critical**: Services must be started in dependency order:

1. **Bitcoin first**: `bitcoin-up` → Wait for sync
2. **Titan second**: `titan-up` → Wait for indexing
3. **Validator last**: `validator-up`

**Stopping**: Reverse order is safe but not required.

## Monitoring

### Status Commands
```bash
# Quick health check of all services
bitcoin-status && echo "---" && titan-status && echo "---" && validator-dashboard

# Individual service status
bitcoin-status               # Bitcoin sync progress, peer connections
titan-status                 # Titan indexing progress, rune count
validator-dashboard          # Validator RPC, network, logs
```

### Service Health Indicators

**Bitcoin (bitcoin-status)**:
- ✅ Service running, blocks syncing
- ✅ Peer connections > 0
- ✅ No persistent errors

**Titan (titan-status)**:
- ✅ Service running, indexing progress
- ✅ Height matches Bitcoin height
- ✅ API responding on port 3030

**Validator (validator-dashboard)**:
- ✅ Service running, RPC responding
- ✅ Connected to local Titan
- ✅ No error messages in logs

### Systemd Service Status
```bash
# Check all arch services
sudo systemctl list-units --type=service --state=active | grep arch

# Individual service status
systemctl status arch-bitcoind@testnet-bitcoin --no-pager
systemctl status arch-titan@testnet-titan --no-pager
systemctl status arch-validator@testnet-validator --no-pager
```

## Maintenance Tasks

### Daily
```bash
# Quick health check
cd validators/testnet
bitcoin-status && titan-status && validator-dashboard

# Check for any service failures
sudo systemctl --failed | grep arch
```

### Weekly
```bash
# System updates
sudo apt update && sudo apt upgrade -y

# Disk usage monitoring
df -h
du -sh /home/testnet-*/data/  # All service data directories

# Log rotation (automatic via systemd)
journalctl --disk-usage
```

### Monthly
```bash
# Binary updates (as needed)
sync-arch-bins
sync-bitcoin-bins
sync-titan-bins

# Restart services after binary updates
validator-down && titan-down && bitcoin-down
bitcoin-up && titan-up && validator-up
```

## Troubleshooting

### Service Won't Start

**Bitcoin issues**:
```bash
# Check Bitcoin logs
journalctl -u arch-bitcoind@testnet-bitcoin -n 50 --no-pager

# Common issues:
# - Insufficient disk space
# - Network connectivity
# - Corrupted blockchain data
```

**Titan issues**:
```bash
# Check Titan logs
journalctl -u arch-titan@testnet-titan -n 50 --no-pager

# Common issues:
# - Bitcoin not running/synced
# - Database corruption (needs --clobber)
# - Network connectivity to Bitcoin RPC
```

**Validator issues**:
```bash
# Check validator logs
journalctl -u arch-validator@testnet-validator -n 50 --no-pager

# Common issues:
# - Titan not running/synced
# - Missing validator identity
# - Network connectivity to Titan API
```

### Service Restart Loop

**Diagnosis**:
```bash
# Check service restart count
systemctl show arch-validator@testnet-validator -p NRestarts --value

# Check recent failures
journalctl -u arch-validator@testnet-validator --since "1 hour ago" -p err
```

**Solutions**:
1. **Check dependencies**: Ensure Bitcoin and Titan are running
2. **Check disk space**: `df -h`
3. **Review configuration**: Check `validators/testnet/.envrc`
4. **Binary issues**: Re-run `sync-*-bins` commands

### High Resource Usage

**Check resource consumption**:
```bash
# CPU/Memory usage by service
systemctl status arch-bitcoind@testnet-bitcoin --no-pager
systemctl status arch-titan@testnet-titan --no-pager
systemctl status arch-validator@testnet-validator --no-pager

# Disk usage
du -sh /home/testnet-*/data/
```

**Typical resource usage**:
- **Bitcoin**: 200-500MB RAM, 20-50GB disk (testnet4)
- **Titan**: 100-200MB RAM, 5-10GB disk
- **Validator**: 50-100MB RAM, 1-5GB disk

### Network Connectivity Issues

**Check service networking**:
```bash
# Verify service ports
sudo ss -tlnp | grep -E "(48332|3030|9002)"

# Test service connectivity
curl -s http://127.0.0.1:3030/status | jq .        # Titan API
curl -s -X POST -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"get_block_count","params":[],"id":1}' http://127.0.0.1:9002/  # Validator RPC
```

## Binary Management

### Production Updates
```bash
# Update to latest releases
sync-arch-bins
sync-bitcoin-bins
sync-titan-bins

# Restart services in dependency order
validator-down && titan-down && bitcoin-down
bitcoin-up && titan-up && validator-up
```

### Development Updates
```bash
# VM-built binaries (requires multipass dev-env)
SYNC_STRATEGY_ARCH=vm sync-arch-bins
SYNC_STRATEGY_BITCOIN=vm sync-bitcoin-bins
sync-titan-bins

# Restart services
validator-down && titan-down && bitcoin-down
bitcoin-up && titan-up && validator-up
```

## Emergency Procedures

### Complete Infrastructure Reset
```bash
# Stop all services and remove all data (WITH BACKUPS)
validator-down --clobber     # Auto-backup before removal
titan-down --clobber         # Auto-backup before removal
bitcoin-down --clobber       # Auto-backup before removal

# Rebuild from scratch
bitcoin-up && titan-up && VALIDATOR_ENCRYPTED_IDENTITY_KEY=backup.age validator-init && validator-up
```

### Service Recovery
```bash
# Restart individual services
systemctl restart arch-bitcoind@testnet-bitcoin
systemctl restart arch-titan@testnet-titan
systemctl restart arch-validator@testnet-validator

# Or use management commands
bitcoin-down && bitcoin-up
titan-down && titan-up
validator-down && validator-up
```

**Need more help?** Check service logs with `journalctl -u <service-name> -f` for real-time troubleshooting.

---

**Quick actions** → This guide | **Initial setup** → [QUICK-START.md](QUICK-START.md) | **Security review** → [SECURITY.md](SECURITY.md) | **Advanced monitoring** → [OBSERVABILITY.md](OBSERVABILITY.md)