# Quick Start: Get Your Validator Running

🎯 **Goal**: Running Arch Network validator with full infrastructure stack in 45 minutes

**What you'll have**: Bitcoin testnet4 node + Titan rune indexer + Arch validator with monitoring.

## Prerequisites

- Ubuntu/Debian server with sudo access
- 8GB+ RAM, 50GB+ disk space (for Bitcoin testnet4)

## Step 1: Install and Setup

```bash
# Clone and setup environment
git clone https://github.com/levicook/arch-valops.git ~/valops && cd ~/valops && direnv allow

# Setup encryption keys (one-time)
setup-age-keys
```

## Step 2: Get Binaries

```bash
# Get official releases (no VM setup needed!)
sync-arch-bins       # Downloads latest Arch Network release
sync-bitcoin-bins    # Downloads Bitcoin Core release
sync-titan-bins      # Downloads Titan rune indexer release
```

## Step 3: Setup Infrastructure (Bitcoin → Titan)

```bash
# Use pre-configured testnet environment
cd validators/testnet && direnv allow

# Start Bitcoin testnet4 node (will sync from network)
bitcoin-up

# Wait for Bitcoin sync (check with: bitcoin-status)
# This takes 20-30 minutes for testnet4

# Start Titan rune indexer (depends on Bitcoin)
titan-up

# Verify infrastructure (check with: titan-status)
```

## Step 4: Create Validator Identity

⚠️ **Do this on a secure/offline machine, then transfer the .age file**

```bash
# Get your host's public key (from step 1)
cat ~/.valops/age/host-identity.pub

# On secure machine - generate and encrypt identity
HOST_PUBLIC_KEY="<your age public key>"  # Use your actual key
validator --generate-peer-id --data-dir $(mktemp -d) | grep secret_key | cut -d'"' -f4 | age -r "$HOST_PUBLIC_KEY" -o validator-identity.age

# Transfer validator-identity.age to your server
```

## Step 5: Initialize and Start Validator

```bash
# Initialize with encrypted identity
VALIDATOR_ENCRYPTED_IDENTITY_KEY=~/validator-identity.age validator-init

# Save the Peer ID shown - you'll need it for registration!

# Start validator (depends on Bitcoin + Titan)
validator-up

# Start monitoring dashboard
validator-dashboard
```

**Dashboard Navigation:**
- `Ctrl+b + n/p`: Switch windows
- `Ctrl+b + d`: Detach (keeps running)

## Step 6: Verify Infrastructure Stack

Check each service is running:

```bash
# Bitcoin node status
bitcoin-status

# Titan indexer status
titan-status

# Validator status (in dashboard)
validator-dashboard
```

In the dashboard, look for:
- ✅ **Status**: "Validator running"
- ✅ **RPC**: Responding on port 9002
- ✅ **Network**: Connected to local Titan (127.0.0.1:3030)
- ✅ **Logs**: No error messages

## Service Dependencies

Your validator runs a complete infrastructure stack:

```
Bitcoin testnet4 node (port 48332)
    ↓
Titan rune indexer (port 3030)
    ↓
Arch validator (port 9002)
```

## Next Steps

🎉 **Congratulations!** Your validator is running with full infrastructure. Now:

1. **Register**: Use your Peer ID with Arch Network
2. **Daily Management**: See [OPERATIONS.md](OPERATIONS.md) for service management
3. **Monitoring**: All services have status commands (`bitcoin-status`, `titan-status`, `validator-dashboard`)

## Infrastructure Management

```bash
# Service control
bitcoin-up / bitcoin-down      # Bitcoin node
titan-up / titan-down          # Titan indexer
validator-up / validator-down  # Validator

# Service status
bitcoin-status                 # Bitcoin sync status
titan-status                   # Titan indexing status
validator-dashboard            # Validator monitoring

# Complete teardown (with backups)
validator-down --clobber
titan-down --clobber
bitcoin-down --clobber
```

## Advanced: Development Setup

**Need custom builds?** For development and testing:

```bash
# VM-built binaries (requires multipass dev-env)
SYNC_STRATEGY_ARCH=vm sync-arch-bins
SYNC_STRATEGY_BITCOIN=vm sync-bitcoin-bins
sync-titan-bins

# Custom configuration
echo "ARCH_WEBSOCKET_ENABLED=true" > .env  # Enable WebSocket
echo "BITCOIN_PRUNE_SIZE=5000" > .env      # Prune Bitcoin to 5GB
```

**Requirements**: Multipass dev-env VM - see [CUSTOM-BINARIES.md](CUSTOM-BINARIES.md) for setup

**Need more help?** See [OPERATIONS.md](OPERATIONS.md) troubleshooting section.

---

**Total setup time**: ~45 minutes (including Bitcoin sync) | **Daily operations?** → [OPERATIONS.md](OPERATIONS.md)