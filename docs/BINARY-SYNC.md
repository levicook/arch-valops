# Binary Synchronization System

🔄 **Flexible binary management with dual strategies: official releases + development builds**

## Overview

The valops project provides a comprehensive binary synchronization system that supports both **official release downloads** and **development VM synchronization**. This dual approach enables both production deployments with verified releases and rapid development cycles with custom builds.

## Architecture

### Strategy-Based Design

```bash
# Release strategy (default) - Download official releases
BITCOIN_VERSION=29.0 sync-bitcoin-bins
ARCH_VERSION=v0.5.3 sync-arch-bins

# VM strategy - Sync from development environment
SYNC_STRATEGY_ARCH=vm sync-arch-bins
SYNC_STRATEGY_BITCOIN=vm sync-bitcoin-bins
sync-titan-bins  # VM-only (no releases available)
```

### Specialized Scripts

| Script              | Binaries                  | Release Strategy  | VM Strategy  |
|---------------------|---------------------------|-------------------|--------------|
| `sync-arch-bins`    | `validator`, `arch-cli`   | ✅ GitHub releases | ✅ dev-env VM |
| `sync-bitcoin-bins` | `bitcoind`, `bitcoin-cli` | ✅ bitcoincore.org | ✅ dev-env VM |
| `sync-titan-bins`   | `titan`                   | ❌ No releases yet | ✅ dev-env VM |

## Environment Variable Interface

All scripts use **environment variables as the primary interface** with backward-compatible flag support:

```bash
# ✅ Recommended: Environment variables
ARCH_VERSION=v0.5.3 sync-arch-bins
BITCOIN_VERSION=29.0 sync-bitcoin-bins

# ✅ Also works: Traditional flags
sync-arch-bins --version v0.5.3
sync-bitcoin-bins --strategy release --version 29.0

# ✅ Best: Pre-configured environments
cd validators/testnet && sync-arch-bins  # Uses configured versions
```

### Environment Variables

#### Strategy Control
- `SYNC_STRATEGY_ARCH` - `release|vm` (default: `release`)
- `SYNC_STRATEGY_BITCOIN` - `release|vm` (default: `release`)
- `SYNC_STRATEGY_TITAN` - `vm` (only option currently)

#### Version Control (Release Strategy Only)
- `ARCH_VERSION` - Arch Network version tag (e.g., `v0.5.3`)
- `BITCOIN_VERSION` - Bitcoin Core version (e.g., `29.0`)

#### VM Configuration (VM Strategy Only)
- `VM_NAME` - Multipass VM name (default: `dev-env`)

## Release Strategy

Downloads official binaries from verified sources:

- **Arch Network**: GitHub releases (`Arch-Network/arch-node`)
- **Bitcoin Core**: Official releases (`bitcoincore.org`)
- **Titan**: Not available (VM strategy only)

### Version Requirements

The release strategy **requires explicit versions** - no "latest" support for predictable deployments:

```bash
# ✅ Required: Explicit versions
ARCH_VERSION=v0.5.3 sync-arch-bins
BITCOIN_VERSION=29.0 sync-bitcoin-bins

# ❌ Not supported: "latest" versions
ARCH_VERSION=latest sync-arch-bins  # Will fail
```

### Conservative Binary Selection

Scripts only install essential binaries:

- **Bitcoin**: `bitcoind` (daemon) + `bitcoin-cli` (client) only
- **Arch**: `validator` + `arch-cli` only
- **No utilities**: `bitcoin-tx`, `bitcoin-util`, etc. excluded for minimal attack surface

### Platform Detection

Automatic platform detection for cross-platform support:

```bash
# Detected automatically
x86_64-unknown-linux-gnu    # Linux x86_64
aarch64-unknown-linux-gnu   # Linux ARM64
x86_64-linux-gnu           # Bitcoin Core naming
aarch64-linux-gnu          # Bitcoin Core naming
```

## VM Strategy

Synchronizes binaries from multipass development VM for rapid iteration:

### Development Workflow

```bash
# 1. Build in VM
multipass exec dev-env -- cd /home/ubuntu/Arch-Network/arch-network && cargo build --release

# 2. Sync to bare metal
SYNC_STRATEGY_ARCH=vm sync-arch-bins

# 3. Test immediately
validator --version
```

### High Performance

VM strategy provides excellent performance:
- **200+ MB/s transfer speeds** via optimized SCP
- **Change detection** - only updates modified binaries
- **Parallel transfers** - each script handles its binaries independently

### Requirements

- Multipass `dev-env` VM running
- SSH access configured to VM
- Binaries built in expected VM paths:
  - Arch: `/home/ubuntu/Arch-Network/arch-network/target/release/`
  - Bitcoin: `/home/ubuntu/bitcoin/src/`
  - Titan: `/home/ubuntu/SaturnBTC/Titan/target/release/`

## Pre-Configured Integration

The binary synchronization system integrates with the validator environments:

```bash
# validators/testnet/.envrc includes:
export SYNC_STRATEGY_ARCH=release
export SYNC_STRATEGY_BITCOIN=release
export SYNC_STRATEGY_TITAN=vm
export ARCH_VERSION=v0.5.3
export BITCOIN_VERSION=29.0
```

This enables simple commands:

```bash
cd validators/testnet
sync-arch-bins      # Uses v0.5.3 from GitHub releases
sync-bitcoin-bins   # Uses 29.0 from bitcoincore.org
sync-titan-bins     # Uses dev-env VM
```

## Usage Examples

### Production Deployment

```bash
# Download verified releases
ARCH_VERSION=v0.5.3 sync-arch-bins
BITCOIN_VERSION=29.0 sync-bitcoin-bins
sync-titan-bins  # VM only option

# Verify installations
validator --version && bitcoind --version && titan --version
```

### Development Workflow

```bash
# Use development builds
SYNC_STRATEGY_ARCH=vm sync-arch-bins
SYNC_STRATEGY_BITCOIN=vm sync-bitcoin-bins
SYNC_STRATEGY_TITAN=vm sync-titan-bins
```

### Mixed Strategy

```bash
# Production Bitcoin + development Arch
BITCOIN_VERSION=29.0 sync-bitcoin-bins
SYNC_STRATEGY_ARCH=vm sync-arch-bins
sync-titan-bins
```

## Error Handling

All scripts provide comprehensive error handling with usage information:

### Version Requirements

```bash
$ sync-arch-bins
lib: Syncing Arch Network binaries...
lib: Strategy: release
lib: ARCH_VERSION must be specified for release strategy
Usage: sync-arch-bins [options]
[... full usage information ...]
```

### Invalid Strategies

```bash
$ SYNC_STRATEGY_ARCH=invalid sync-arch-bins
lib: Unknown strategy: invalid (supported: release, vm)
Usage: sync-arch-bins [options]
[... full usage information ...]
```

### Connection Issues

```bash
$ SYNC_STRATEGY_ARCH=vm sync-arch-bins
lib: ✗ Could not get IP for VM: dev-env
```

## Implementation Details

### Atomic Operations

All binary installations use atomic operations:

1. **Download to temp file** - Never corrupt existing binaries
2. **Compare checksums** - Only update when changed
3. **Atomic move** - Replace binary in single operation
4. **Permissions** - Set executable permissions correctly

### Exact Asset Matching

Release downloads use exact asset name matching to avoid ambiguity:

```bash
# Exact match prevents confusion between:
# - validator vs local_validator
# - arch-cli vs other arch-* binaries
expected_asset_name="${binary_name}-${platform}"
```

### Shared Library

`sync-lib.sh` provides common functionality:

- `sync_binary_from_vm()` - VM synchronization
- `download_github_binary()` - GitHub release downloads
- `get_platform()` - Platform detection
- `get_vm_ip()` - VM IP discovery

### Logging

Consistent logging across all scripts:

```bash
lib: Syncing Arch Network binaries...
lib: Strategy: release
lib: Version: v0.5.3, Platform: x86_64-unknown-linux-gnu
lib: Downloading validator from releases (Arch-Network/arch-node)...
lib: ✓ Downloaded validator
lib: ✓ Arch Network binaries sync complete
```

## Troubleshooting

### Binary Not Found in Release

```bash
lib: ✗ Binary not found: validator-x86_64-unknown-linux-gnu in Arch-Network/arch-node v0.5.3
```

**Solutions:**
- Check version exists: `curl -s https://api.github.com/repos/Arch-Network/arch-node/releases`
- Verify platform name in release assets
- Use VM strategy as fallback: `SYNC_STRATEGY_ARCH=vm sync-arch-bins`

### VM Connection Issues

```bash
lib: ✗ Could not get IP for VM: dev-env
```

**Solutions:**
```bash
# Check VM status
multipass list

# Start VM
multipass start dev-env

# Test SSH
multipass exec dev-env -- echo "test"
```

### Text File Busy

```bash
cp: cannot create regular file '/usr/local/bin/validator': Text file busy
```

**Cause:** Binary is currently running
**Solution:** Stop process first:

```bash
# Stop validator
validator-down --user testnet-validator

# Then sync
ARCH_VERSION=v0.5.3 sync-arch-bins

# Restart validator
validator-up --user testnet-validator
```

## Migration from Legacy sync-bins

The old monolithic `sync-bins` script has been replaced with specialized scripts:

### Old Pattern
```bash
# Single script, VM-only, hardcoded binaries
sync-bins
```

### New Pattern
```bash
# Specialized scripts, dual strategies, configurable
SYNC_STRATEGY_ARCH=vm sync-arch-bins      # arch-cli + validator
SYNC_STRATEGY_BITCOIN=vm sync-bitcoin-bins # bitcoind + bitcoin-cli
sync-titan-bins                           # titan (VM-only)
```

### Benefits of New System

1. **Dual strategies** - Release downloads + VM synchronization
2. **Conservative binary lists** - Only essential binaries
3. **Explicit version control** - No surprise "latest" updates
4. **Environment integration** - Works with direnv/pre-configured environments
5. **Better error handling** - Clear usage information on failures
6. **Specialized responsibility** - Each script handles its domain
7. **Maintainable** - Single source of truth for binary lists

## Future Enhancements

- **Signature verification** for release downloads
- **Titan release support** when SaturnBTC/Titan publishes releases
- **Multi-VM support** for different development environments
- **Binary caching** to avoid repeated downloads
- **Rollback capability** to previous versions