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

**Option A: Official Releases (Recommended for Production)**
```bash
ARCH_VERSION=v0.5.3 sync-arch-bins
BITCOIN_VERSION=29.0 sync-bitcoin-bins
```

**Option B: Development VM (For Testing)**
```bash
# Requires multipass dev-env VM - see CONTRIBUTING.md for setup
SYNC_STRATEGY_ARCH=vm sync-arch-bins
SYNC_STRATEGY_BITCOIN=vm sync-bitcoin-bins
sync-titan-bins
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

## Common Issues

### "Age command not found"
```bash
sudo apt install -y age
```

### "VM connection refused" (Option B only)
```bash
multipass list && multipass start dev-env
```

### "Binary not found"
Re-run step 2 with correct binary sync commands.

### "Validator won't start"
Check logs in dashboard or run: `tail -f /home/testnet-validator/logs/validator.log`

**Need more help?** See [OPERATIONS.md](OPERATIONS.md) troubleshooting section.

---

**Total setup time**: ~30 minutes | **Need production security?** → [SECURITY.md](SECURITY.md) | **Daily operations?** → [OPERATIONS.md](OPERATIONS.md)