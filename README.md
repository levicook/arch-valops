# Arch Network Validator Operations (valops)

🏗️ **Infrastructure-as-Code toolkit for secure Arch Network validator operations with hybrid development architecture and comprehensive monitoring dashboard**

## Key Features

- 🔐 **Secure Identity Management** - Secure peer identity lifecycle with automatic backup/restore
- 📊 **Real-Time Monitoring** - Comprehensive tmux dashboard with process, network, and log monitoring
- 🚀 **Hybrid Development Model** - Build in VMs, deploy on bare metal for optimal performance
- 🔄 **Infrastructure-as-Code** - Idempotent, version-controlled validator operations
- 🌐 **Zero-Trust Deployment** - SSH tunneling with agent forwarding, no credentials stored on servers
- ⚡ **Clean Environment Interface** - Environment variable-driven with excellent direnv integration

## Quick Start

**🚀 New to valops?** → **[QUICK-START.md](docs/QUICK-START.md)** - Get running in 30 minutes

**The fastest path**: Published releases + remote titan service = no VM setup needed!

```bash
git clone https://github.com/levicook/arch-valops.git ~/valops && cd ~/valops && direnv allow
setup-age-keys
sync-arch-bins && sync-bitcoin-bins  # No titan binary needed!
cd validators/testnet && validator-init && validator-up
```

## Modern Systemd Architecture

The system uses **systemd services** for all process management:

```bash
# Service management (current reality)
systemctl status arch-validator@testnet-validator    # Check status
systemctl start arch-validator@testnet-validator     # Start service
systemctl stop arch-validator@testnet-validator      # Stop service
journalctl -u arch-validator@testnet-validator -f    # View logs

# Script integration (IaC approach)
validator-up     # Ensures service is running
validator-down   # Stops service cleanly
```

## Modern Environment-Driven Interface

All scripts now use **environment variables first** with backward compatibility for flags:

```bash
# ✅ Recommended: Environment variables
VALIDATOR_USER=testnet-validator validator-up

# ✅ Also works: Traditional flags (backward compatibility)
validator-up --user testnet-validator

# ✅ Best: Pre-configured environments
cd validators/testnet && validator-up  # Uses VALIDATOR_USER=testnet-validator automatically
```

### Pre-Configured Environments

The project includes ready-to-use validator environments with sensible defaults:

```bash
# Testnet validator (remote titan - no local indexer needed)
cd validators/testnet && direnv allow
# Sets: VALIDATOR_USER=testnet-validator, ARCH_TITAN_MODE=remote, endpoints, etc.

# Mainnet validator (remote titan - production ready)
cd validators/mainnet && direnv allow
# Sets: VALIDATOR_USER=mainnet-validator, ARCH_TITAN_MODE=remote, endpoints, etc.

# Development network (local titan - for testing)
cd validators/devnet && direnv allow
# Sets: VALIDATOR_USER=devnet-validator, ARCH_TITAN_MODE=local, endpoints, etc.
```

**Customization**: Create `.env` file in any validator directory to override defaults:
```bash
cd validators/testnet
echo "VALIDATOR_USER=my-custom-validator" > .env
# Now validator-up uses my-custom-validator instead of testnet-validator
```

## Architecture at a Glance

This toolkit implements a **hybrid development model** that separates build and runtime environments:

- **Development VM**: Build binaries in isolated multipass `dev-env` VM
- **Bare Metal Deployment**: Run validators on bare metal for optimal performance
- **SSH Tunneling**: Secure development workflow with credential isolation
- **Key Separation**: Development keys completely isolated from validator signing keys

The architecture ensures that even complete compromise of development infrastructure cannot access validator funds or signing keys.

## Identity Management

**Problem**: Validator peer identities are critical single points of failure. Loss of the `identity-secret` file means permanent loss of the validator. Traditional approaches rely on manual backup/restore processes that are error-prone.

**Solution**: Pragmatic encrypted identity lifecycle management that treats peer identity as a protected asset.

### Identity Management

```bash
# Initialize validator (auto-creates backup)
cd validators/testnet
VALIDATOR_ENCRYPTED_IDENTITY_KEY=validator-identity.age validator-init
# Tells you if original file is safe to delete

# Backup stored at: ~/.valops/age/identity-backup-{peer-id}.age
```

**Recovery Process:**
```bash
# Restore from backup (same process as original deployment)
VALIDATOR_ENCRYPTED_IDENTITY_KEY=~/.valops/age/identity-backup-{peer-id}.age validator-init

# Always create new backup after recovery
backup-identities
```

**Emergency Protection:**
```bash
# Destructive operations create emergency backups automatically
validator-down --clobber
# → Creates backup first, refuses to proceed if backup fails
```

**Automatic Protection:**
- Init creates encrypted backups automatically
- Destructive operations backup before proceeding
- Backups work across different hosts
- All backups encrypted with age keys

## Documentation

**📚 Complete documentation** organized by role and use case:

| Guide                                                     | For            | Focus                             |
|-----------------------------------------------------------|----------------|-----------------------------------|
| **[QUICK-START.md](docs/QUICK-START.md)**                 | New users      | Get running in 30 minutes         |
| **[OPERATIONS.md](docs/OPERATIONS.md)**                   | Prod operators | Daily management                  |
| **[SECURITY.md](docs/SECURITY.md)**                       | Security teams | Threat analysis & recommendations |
| **[MANAGEMENT.md](docs/MANAGEMENT.md)**                   | Existing users | Binary updates & migrations       |
| **[OBSERVABILITY.md](docs/OBSERVABILITY.md)**             | SRE/DevOps     | Monitoring & automation           |
| **[DEVELOPMENT.md](docs/DEVELOPMENT.md)**                 | Contributors   | Architecture & development        |
| **[CUSTOM-BINARIES.md](docs/CUSTOM-BINARIES.md)**         | Advanced users | Running modified binaries         |
| **[IDENTITY-GENERATION.md](docs/IDENTITY-GENERATION.md)** | Security teams | Offline identity creation         |

## Project Structure

```
valops/
├── .envrc                            # Root environment (adds bin/ to PATH)
├── bin/                              # All executable scripts
├── libs/                             # Source-friendly library functions
│   ├── backup-identities             # Backup all validator identities
│   ├── lib.sh                        # Shared utilities library
│   ├── setup-age-keys                # Age encryption keypair setup
│   ├── sync-arch-bins                # Arch Network binary synchronization
│   ├── sync-bitcoin-bins             # Bitcoin Core binary synchronization
│   ├── sync-lib.sh                   # Shared sync utilities
│   ├── sync-titan-bins               # Titan binary synchronization
│   ├── system-status                 # Host security assessment tool
│   ├── validator-dashboard           # Comprehensive monitoring dashboard
│   ├── validator-down                # Stop validator process
│   ├── validator-init                # One-time validator initialization
│   └── validator-up                  # Start validator process
├── validators/                       # Pre-configured environments
│   ├── testnet/.envrc                # Testnet configuration
│   ├── mainnet/.envrc                # Mainnet configuration
│   └── devnet/.envrc                 # Devnet configuration
├── systemd/
│   ├── arch-validator@.service       # Validator systemd unit
│   ├── arch-bitcoind@.service        # Bitcoin systemd unit
│   └── arch-titan@.service           # Titan systemd unit
└── docs/                             # Streamlined documentation (8 focused guides)
```

## Core Operations

### Security Assessment
```bash
system-status   # Comprehensive host security assessment (run first)
```

### Binary Management

**Production Path (Recommended):**
```bash
setup-age-keys       # Setup age encryption keys (one-time)
sync-arch-bins       # Download latest Arch Network release
sync-bitcoin-bins    # Download Bitcoin Core release
# No titan binary needed - uses remote titan service!
```

**Development Path (Advanced):**
```bash
sync-titan-bins                            # Sync Titan binary (vm strategy only)
SYNC_STRATEGY_ARCH=vm sync-arch-bins       # Arch binaries from dev VM
SYNC_STRATEGY_BITCOIN=vm sync-bitcoin-bins # Bitcoin binaries from dev VM
```

### Validator Lifecycle

**Using Pre-configured Environments (Recommended):**
```bash
# Initialize mainnet validator (uses remote titan)
cd validators/mainnet
VALIDATOR_ENCRYPTED_IDENTITY_KEY=validator-identity.age validator-init
validator-up

# Monitor
validator-dashboard
```

**Custom Configuration:**
```bash
# Environment variables (recommended)
VALIDATOR_USER=my-validator ARCH_NETWORK_MODE=testnet validator-init
VALIDATOR_USER=my-validator validator-up

# Or traditional flags (backward compatibility)
validator-init --user my-validator --network testnet
validator-up --user my-validator
```

### Operations
```bash
# Daily operations
validator-dashboard                    # Real-time monitoring dashboard
backup-identities                     # Manual backup of all identities
system-status                         # Security and resource assessment

# Maintenance
validator-down && validator-up         # Clean restart
validator-down --clobber              # Complete removal (with backup)
```

## Advanced Features

### Development VM Integration
```bash
# Build custom binaries in isolated VM
multipass launch --name dev-env --memory 4G --disk 20G --cpus 2
# See CUSTOM-BINARIES.md for complete VM setup

# Sync custom builds
SYNC_STRATEGY_ARCH=vm sync-arch-bins
sync-titan-bins
```

### Identity Security
```bash
# Offline identity generation (air-gapped machine)
validator --generate-peer-id --data-dir $(mktemp -d) | grep secret_key | cut -d'"' -f4 | age -r "$HOST_PUBLIC_KEY" -o validator-identity.age

# Deploy encrypted identity
VALIDATOR_ENCRYPTED_IDENTITY_KEY=validator-identity.age validator-init
```

### Network Flexibility
```bash
# Multiple networks supported
cd validators/testnet && validator-up    # Testnet
cd validators/mainnet && validator-up    # Mainnet  
cd validators/devnet && validator-up     # Development
```

## Contributing

See **[DEVELOPMENT.md](docs/DEVELOPMENT.md)** for:
- Architecture decisions and patterns
- Development environment setup
- Testing procedures
- Contribution guidelines

## Security

See **[SECURITY.md](docs/SECURITY.md)** for:
- Threat model and security architecture
- Key management best practices
- Production deployment recommendations
- Security assessment procedures
