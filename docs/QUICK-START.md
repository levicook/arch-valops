# Quick Start: Get Your Validator Running

🎯 **Goal**: Running Arch Network validator in 30 minutes

**What you'll have**: A secure validator with encrypted identity and monitoring dashboard.

## Prerequisites

- Ubuntu/Debian server with sudo access
- 4GB+ RAM, 20GB+ disk space

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
```

## Step 3: Create Validator Identity

⚠️ **Do this on a secure/offline machine, then transfer the .age file**

```bash
# Get your host's public key (from step 1)
cat ~/.valops/age/host-identity.pub

# On secure machine - generate and encrypt identity
HOST_PUBLIC_KEY="<your age public key>"  # Use your actual key
validator --generate-peer-id --data-dir $(mktemp -d) | grep secret_key | cut -d'"' -f4 | age -r "$HOST_PUBLIC_KEY" -o validator-identity.age

# Transfer validator-identity.age to your server
```

## Step 4: Initialize Validator

```bash
# Use pre-configured testnet environment
cd validators/testnet && direnv allow

# Initialize with encrypted identity
VALIDATOR_ENCRYPTED_IDENTITY_KEY=~/validator-identity.age validator-init

# Save the Peer ID shown - you'll need it for registration!
```

## Step 5: Start Validator

```bash
# Start validator
validator-up

# Start monitoring dashboard
validator-dashboard
```

**Dashboard Navigation:**
- `Ctrl+b + n/p`: Switch windows
- `Ctrl+b + d`: Detach (keeps running)

## Step 6: Verify It's Working

In the dashboard, look for:
- ✅ **Status**: "Validator running"
- ✅ **RPC**: Responding on port 9002
- ✅ **Network**: Connected to Titan
- ✅ **Logs**: No error messages

## Next Steps

🎉 **Congratulations!** Your validator is running. Now:

1. **Register**: Use your Peer ID with Arch Network
2. **Production Setup**: Review [SECURITY.md](SECURITY.md) for production deployment
3. **Daily Management**: See [OPERATIONS.md](OPERATIONS.md) for maintenance
4. **Binary Management**: See [MANAGEMENT.md](MANAGEMENT.md) for updates
5. **Monitoring**: See [OBSERVABILITY.md](OBSERVABILITY.md) for advanced monitoring

## Advanced: Development Setup

**Need local titan or custom builds?** For development and testing:

```bash
# For local titan indexer + VM-built binaries
SYNC_STRATEGY_ARCH=vm sync-arch-bins       # Arch binaries from dev VM  
SYNC_STRATEGY_BITCOIN=vm sync-bitcoin-bins # Bitcoin binaries from dev VM
sync-titan-bins                            # Titan binary from dev VM

# Use testnet with local titan
cd validators/testnet && echo "TITAN_MODE=local" > .env
validator-up                               # Runs local titan indexer
```

**Requirements**: Multipass dev-env VM - see [CUSTOM-BINARIES.md](CUSTOM-BINARIES.md) for setup

**Need more help?** See [OPERATIONS.md](OPERATIONS.md) troubleshooting section.

---

**Total setup time**: ~30 minutes | **Need production security?** → [SECURITY.md](SECURITY.md) | **Daily operations?** → [OPERATIONS.md](OPERATIONS.md)