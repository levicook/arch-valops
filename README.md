# Valops: Arch Network Validator Operations

🚀 **Production-ready infrastructure for Arch Network validators**

Complete infrastructure stack: Bitcoin testnet4 → Titan rune indexer → Arch validator

## Quick Start

Get your validator running in ~45 minutes:

```bash
# 1. Setup
git clone https://github.com/levicook/arch-valops.git ~/valops && cd ~/valops && direnv allow
setup-age-keys

# 2. Get binaries
sync-arch-bins && sync-bitcoin-bins && sync-titan-bins

# 3. Start infrastructure (in dependency order)
cd validators/testnet && direnv allow
bitcoin-up        # Bitcoin testnet4 node (20-30 min sync)
titan-up          # Titan rune indexer (depends on Bitcoin)

# 4. Setup validator identity (secure machine)
# See docs/QUICK-START.md for identity generation

# 5. Start validator
VALIDATOR_ENCRYPTED_IDENTITY_KEY=~/validator-identity.age validator-init
validator-up
validator-dashboard
```

**👉 [Complete setup guide](docs/QUICK-START.md)**

## Service Management

**Infrastructure services** (run in dependency order):
- `bitcoin-up` / `bitcoin-down` - Bitcoin testnet4 node
- `titan-up` / `titan-down` - Titan rune indexer  
- `validator-up` / `validator-down` - Arch validator

**Status monitoring**:
- `bitcoin-status` - Bitcoin sync progress
- `titan-status` - Titan indexing status
- `validator-dashboard` - Validator monitoring

**👉 [Daily operations guide](docs/OPERATIONS.md)**

## Service Architecture

```
Bitcoin testnet4 node (port 48332)
    ↓
Titan rune indexer (port 3030)
    ↓
Arch validator (port 9002)
```

Each service runs as a systemd service with dedicated user accounts and data directories.

## Current Focus

**Testnet-ready**: This setup is optimized for Arch Network testnet operations with:
- Bitcoin testnet4 (full node with txindex)
- Titan rune indexer (local Bitcoin integration)
- Arch validator (testnet configuration)

## Documentation

- **[Quick Start](docs/QUICK-START.md)** - Get running in 45 minutes
- **[Operations Guide](docs/OPERATIONS.md)** - Daily management and troubleshooting
- **[Custom Binaries](docs/CUSTOM-BINARIES.md)** - Development builds via multipass
- **[Management Guide](docs/MANAGEMENT.md)** - Advanced configuration

## Requirements

- **System**: Ubuntu/Debian with sudo access
- **Resources**: 8GB+ RAM, 50GB+ disk (for Bitcoin testnet4)
- **Network**: Stable internet connection for blockchain sync

## Support

- **Status commands**: `bitcoin-status`, `titan-status`, `validator-dashboard`
- **Logs**: `journalctl -u arch-bitcoind@testnet-bitcoin -f`
- **Troubleshooting**: See [Operations Guide](docs/OPERATIONS.md)

---

**Architecture**: Service-specific users, systemd management, RPC helper functions  
**Security**: Encrypted identity keys, local-only RPC binding, automatic backups
