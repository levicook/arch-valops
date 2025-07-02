# Management Guide

🔄 **For**: Existing operators managing validators and upgrades
🎯 **Focus**: Binary management, version upgrades, migration procedures

## Binary Management

### Quick Reference
```bash
# Production (official releases - recommended)
ARCH_VERSION=v0.5.3 sync-arch-bins
BITCOIN_VERSION=29.0 sync-bitcoin-bins

# Development (VM builds - for testing)
SYNC_STRATEGY_ARCH=vm sync-arch-bins
SYNC_STRATEGY_BITCOIN=vm sync-bitcoin-bins
sync-titan-bins  # VM-only (no releases available)

# Restart after binary updates
validator-down && validator-up
```

### Binary Sync Architecture

**Dual Strategy System**: Each binary type supports two sync strategies:

| Binary       | Script              | Release Strategy  | VM Strategy  |
|--------------|---------------------|-------------------|--------------|
| Arch Network | `sync-arch-bins`    | ✅ GitHub releases | ✅ dev-env VM |
| Bitcoin Core | `sync-bitcoin-bins` | ✅ bitcoincore.org | ✅ dev-env VM |
| Titan        | `sync-titan-bins`   | ❌ No releases yet | ✅ dev-env VM |

### Production Binary Management

**Use explicit versions** - no "latest" support for predictable deployments:

```bash
# ✅ Required: Explicit versions
ARCH_VERSION=v0.5.3 sync-arch-bins
BITCOIN_VERSION=29.0 sync-bitcoin-bins

# ❌ Not supported: "latest" versions
ARCH_VERSION=latest sync-arch-bins  # Will fail
```

**Conservative binary selection** - only essential binaries installed:
- **Arch**: `validator` + `arch-cli` only
- **Bitcoin**: `bitcoind` + `bitcoin-cli` only
- **Titan**: `titan` only

### Development Binary Management

**VM strategy** for rapid iteration during development:

```bash
# Sync from development VM
SYNC_STRATEGY_ARCH=vm sync-arch-bins
SYNC_STRATEGY_BITCOIN=vm sync-bitcoin-bins
sync-titan-bins

# High performance: 200+ MB/s transfers
# Change detection: only updates modified binaries
```

**Requirements**:
- Multipass `dev-env` VM running
- SSH access configured
- Binaries built in expected VM paths

### Environment Integration

**Pre-configured environments** make binary management simple:

```bash
# validators/testnet/.envrc includes:
export ARCH_VERSION=v0.5.3
export BITCOIN_VERSION=29.0
export SYNC_STRATEGY_ARCH=release
export SYNC_STRATEGY_BITCOIN=release

# Usage:
cd validators/testnet
sync-arch-bins      # Uses v0.5.3 from GitHub
sync-bitcoin-bins   # Uses 29.0 from bitcoincore.org
```

### Binary Update Procedures

**Safe update process**:
```bash
# 1. Stop validator first (prevents "text file busy" errors)
validator-down

# 2. Update binaries
ARCH_VERSION=v0.5.4 sync-arch-bins
BITCOIN_VERSION=29.1 sync-bitcoin-bins

# 3. Restart validator
validator-up

# 4. Verify updates
validator --version && bitcoind --version
```

**Emergency rollback**:
```bash
# Roll back to previous versions
ARCH_VERSION=v0.5.3 sync-arch-bins
BITCOIN_VERSION=29.0 sync-bitcoin-bins
validator-down && validator-up
```

## Migration and Upgrades

### Migration from Legacy sync-bins

**Old system** (deprecated):
```bash
sync-bins  # Single script, VM-only, hardcoded binaries
```

**New system**:
```bash
# Specialized scripts with dual strategies
ARCH_VERSION=v0.5.3 sync-arch-bins      # Arch Network binaries
BITCOIN_VERSION=29.0 sync-bitcoin-bins   # Bitcoin Core binaries
sync-titan-bins                         # Titan binary
```

**Migration steps**:
1. **Update scripts**: New sync scripts are already installed
2. **Update documentation references**: Replace `sync-bins` with specific scripts
3. **Update CI/CD**: Replace `sync-bins` calls in automation
4. **Test new workflow**: Verify binary sync with both strategies

### Version Upgrade Procedures

**Planning upgrades**:
1. **Check release notes** for breaking changes
2. **Test in development** environment first
3. **Schedule maintenance window** for production
4. **Prepare rollback plan** with previous versions

**Upgrade execution**:
```bash
# 1. Backup current state
VALIDATOR_USER=testnet-validator backup-identities  # Automatic identity backup

# 2. Stop validator
validator-down

# 3. Update system packages
sudo apt update && sudo apt upgrade -y

# 4. Update valops tooling
cd ~/valops && git pull

# 5. Update binaries
ARCH_VERSION=v0.5.4 sync-arch-bins
BITCOIN_VERSION=29.1 sync-bitcoin-bins

# 6. Restart validator
validator-up

# 7. Monitor for issues
validator-dashboard  # Watch for errors
```

**Post-upgrade verification**:
```bash
# Verify binary versions
validator --version
bitcoind --version

# Check validator health
curl -X POST -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"get_block_count","params":[],"id":1}' http://127.0.0.1:9002/

# Monitor logs for errors
tail -f /home/testnet-validator/logs/validator.log
```

### Environment Migration

**From old structure** (scripts in root) **to new structure** (executables in bin/, libraries in libs/):

**Old pattern**:
```bash
cd ~/valops
./validator-up  # Scripts in root directory
```

**New pattern**:
```bash
# Scripts automatically in PATH with direnv
cd ~/valops && direnv allow  # One-time setup
validator-up  # Works from anywhere
```

**Migration checklist**:
- [ ] Update shell scripts/aliases that reference old paths (scripts/ → bin/ and libs/)
- [ ] Update CI/CD pipelines with new script locations
- [ ] Train team on new directory-agnostic operation
- [ ] Test pre-configured validator environments

### Data Migration

**Identity files** automatically compatible - no migration needed:
```bash
# Old and new systems use same identity format
# Existing encrypted identity files work without changes
VALIDATOR_ENCRYPTED_IDENTITY_KEY=existing-identity.age validator-init
```

**Configuration migration**:
```bash
# Environment variables replace command flags
# Old: validator-up --user testnet-validator
# New: VALIDATOR_USER=testnet-validator validator-up

# Or use pre-configured environments:
cd validators/testnet  # Sets VALIDATOR_USER automatically
validator-up
```

## Troubleshooting

### Binary Sync Issues

**"Binary not found in release"**:
```bash
# Check if version exists
curl -s https://api.github.com/repos/Arch-Network/arch-node/releases | jq '.[].tag_name'

# Use VM strategy as fallback
SYNC_STRATEGY_ARCH=vm sync-arch-bins
```

**"VM connection refused"**:
```bash
# Check VM status
multipass list

# Start VM if needed
multipass start dev-env

# Test connectivity
multipass exec dev-env -- echo "test"
```

**"Text file busy"** (binary in use):
```bash
# Stop validator first
validator-down

# Then update binaries
ARCH_VERSION=v0.5.4 sync-arch-bins

# Restart
validator-up
```

### Migration Issues

**Scripts not found after migration**:
```bash
# Ensure direnv is properly configured
cd ~/valops && direnv allow

# Verify PATH includes scripts directory
echo $PATH | grep valops/scripts
```

**Environment variables not loading**:
```bash
# Check .envrc files
cat validators/testnet/.envrc

# Manually source if needed
source validators/testnet/.envrc
```

**Permission errors**:
```bash
# Fix script permissions
chmod +x bin/sync-*-bins bin/validator-*
```

## Best Practices

### Version Management
- **Pin versions** in production environments
- **Test upgrades** in development first
- **Document version choices** for audit trails
- **Monitor security advisories** for urgent updates

### Binary Management
- **Use release strategy** for production deployments
- **Use VM strategy** for development/testing
- **Verify binaries** after updates (`--version` checks)
- **Monitor binary sizes** for unexpected changes

### Change Management
- **Version control** all configuration changes
- **Peer review** upgrade procedures
- **Document rollback procedures** before upgrades
- **Test backup/restore** procedures regularly

### Automation
- **Script version checks** in monitoring systems
- **Automate security updates** for system packages
- **Alert on binary version drift** across environments
- **Integrate upgrade procedures** with change management

---

**Binary issues?** → Check troubleshooting above | **Operational questions?** → [OPERATIONS.md](OPERATIONS.md) | **Security concerns?** → [SECURITY.md](SECURITY.md)