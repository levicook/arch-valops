# Arch Network Validator Operations (valops)

🏗️ **Infrastructure-as-Code toolkit for secure Arch Network validator operations with hybrid development architecture and comprehensive monitoring dashboard**

## Key Features

- 🔐 **Encrypted Identity Management** - Secure peer identity lifecycle with automatic backup/restore
- 🔒 **Security-First Architecture** - Complete isolation of signing keys from development infrastructure
- 📊 **Real-Time Monitoring** - Comprehensive tmux dashboard with process, network, and log monitoring  
- 🚀 **Hybrid Development Model** - Build in VMs, deploy on bare metal for optimal performance
- 🔄 **Infrastructure-as-Code** - Idempotent, version-controlled validator operations
- 🌐 **Zero-Trust Deployment** - SSH tunneling with agent forwarding, no credentials stored on servers
- ⚡ **Clean Environment Interface** - Environment variable-driven with excellent direnv integration

## Quick Start

The fastest way to get started is using the pre-configured validator environments:

```bash
# 1. Clone and setup
git clone https://github.com/levicook/arch-valops.git ~/valops && cd ~/valops && direnv allow
# direnv: loading ~/valops/.envrc
# 🔧 valops project environment loaded
# Scripts available: validator-init, validator-up, validator-down, etc.
# direnv: export ~PATH

# 2. Setup age encryption keys (one-time)
setup-age-keys

# 3. Sync latest binaries from dev VM (if using hybrid development)
sync-bins

# 4. Use pre-configured testnet environment
cd validators/testnet
direnv allow
# 🔧 Testnet validator environment loaded
#   VALIDATOR_USER=testnet-validator
#   ARCH_NETWORK_MODE=testnet

# 5. Initialize validator with encrypted identity (one-time)
VALIDATOR_ENCRYPTED_IDENTITY_KEY=~/validator-identity.age validator-init

# 6. Start validator
validator-up

# 7. Monitor with comprehensive dashboard
validator-dashboard

# 8. Stop validator
validator-down
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
# Testnet validator
cd validators/testnet && direnv allow
# Sets: VALIDATOR_USER=testnet-validator, ARCH_NETWORK_MODE=testnet, endpoints, etc.

# Mainnet validator  
cd validators/mainnet && direnv allow
# Sets: VALIDATOR_USER=mainnet-validator, ARCH_NETWORK_MODE=mainnet, endpoints, etc.

# Development network
cd validators/devnet && direnv allow
# Sets: VALIDATOR_USER=devnet-validator, ARCH_NETWORK_MODE=devnet, endpoints, etc.
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

## Project Structure

```
valops/
├── .envrc                            # Root environment (adds scripts/ to PATH)
├── scripts/                          # All executable scripts
│   ├── lib.sh                        # Shared utilities library
│   ├── check-env                     # Host security assessment tool
│   ├── setup-age-keys                # Age encryption keypair setup
│   ├── backup-identities             # Backup all validator identities
│   ├── validator-init                # One-time validator initialization
│   ├── validator-up                  # Start validator process
│   ├── validator-down                # Stop validator process
│   ├── validator-dashboard           # Comprehensive monitoring dashboard
│   └── sync-bins                     # Binary synchronization from dev VM
├── validators/                       # Pre-configured environments
│   ├── testnet/.envrc                # Testnet configuration
│   ├── mainnet/.envrc                # Mainnet configuration
│   └── devnet/.envrc                 # Devnet configuration
├── resources/                        # Deployable validator scripts
│   ├── run-validator                 # Validator startup script
│   └── halt-validator                # Validator shutdown script
└── docs/                             # Detailed documentation
    ├── API.md                        # Utility function reference
    ├── ARCHITECTURE.md               # Development architecture
    ├── DEVELOPMENT.md                # Testing and development workflow
    ├── IDENTITY-GENERATION.md        # Secure identity creation workflow
    ├── MIGRATION.md                  # Migration guide from older versions
    ├── MONITORING.md                 # Monitoring and observability
    ├── OPERATIONS.md                 # Operational procedures
    ├── QUICK-START.md                # Complete setup walkthrough
    └── SECURITY.md                   # Security model and analysis
```

## Core Operations

### Security Assessment
```bash
check-env   # Comprehensive host security assessment (run first)
```

### Environment Setup
```bash
setup-age-keys  # Setup age encryption keys (one-time)
sync-bins       # Sync latest binaries from development VM
```

### Validator Lifecycle

**Using Pre-configured Environments (Recommended):**
```bash
# Initialize testnet validator
cd validators/testnet
VALIDATOR_ENCRYPTED_IDENTITY_KEY=validator-identity.age validator-init

# Start, monitor, stop
validator-up
validator-dashboard
validator-down
```

**Using Environment Variables:**
```bash
# Initialize validator
VALIDATOR_USER=testnet-validator ARCH_NETWORK_MODE=testnet VALIDATOR_ENCRYPTED_IDENTITY_KEY=validator-identity.age validator-init

# Start, monitor, stop
VALIDATOR_USER=testnet-validator validator-up
VALIDATOR_USER=testnet-validator validator-dashboard
VALIDATOR_USER=testnet-validator validator-down
```

**Using Traditional Flags:**
```bash
validator-init --user testnet-validator --network testnet --encrypted-identity-key validator-identity.age
validator-up --user testnet-validator
validator-down --user testnet-validator
```

## Monitoring Dashboard

The `validator-dashboard` provides real-time observability through a sophisticated tmux interface:

```bash
# Using pre-configured environment
cd validators/testnet && validator-dashboard

# Using environment variables
VALIDATOR_USER=testnet-validator validator-dashboard

# Using flags
validator-dashboard --user testnet-validator
```

**Dashboard Features:**
- **Status Monitoring**: Real-time validator health, network connectivity, data metrics
- **Live Logs**: Streaming validator activity with error highlighting
- **System Resources**: CPU, memory, and network usage monitoring
- **Operational Guidance**: Built-in help and troubleshooting commands

**Navigation:**
- `Ctrl+b + n/p`: Switch windows | `Ctrl+b + arrows`: Switch panes | `Ctrl+b + d`: Detach

## Directory-Agnostic Operation

All scripts work from any directory thanks to intelligent project root detection:

```bash
# Works from project root
cd ~/valops && validator-up

# Works from subdirectories  
cd ~/valops/docs && validator-up

# Works from pre-configured environments
cd ~/valops/validators/testnet && validator-up

# Works from anywhere if scripts/ is in PATH
cd ~ && validator-up
```

## Environment Integration

### direnv Integration (Recommended)

1. **Install direnv**: `sudo apt install direnv` (or your package manager)
2. **Hook into shell**: `echo 'eval "$(direnv hook bash)"' >> ~/.bashrc`
3. **Use pre-configured environments**:
   ```bash
   cd validators/testnet
   direnv allow
   # Environment automatically loaded with all necessary variables
   ```

### Manual Setup

If not using direnv, you can source environments manually:
```bash
source validators/testnet/.envrc
validator-up  # Uses testnet configuration
```

## Security Model

This toolkit implements **defense in depth** with multiple isolation layers:

1. **Development Keys** (SSH, GPG, GitHub) - Isolated to developer laptop via agent forwarding
2. **Infrastructure Keys** - Minimal scope server access keys  
3. **Validator Signing Keys** - Completely separate, hardware-secured, never touched by this toolkit

**Security Guarantee**: Even total compromise of valops infrastructure cannot access validator funds.

## Migration Notes

**🚀 Upgrading from older valops?** See **[MIGRATION.md](docs/MIGRATION.md)** for a complete migration guide with examples.

**Quick summary of changes:**
- **Scripts moved**: All scripts now in `scripts/` directory (automatically in PATH with direnv)
- **Interface changed**: Environment variables preferred over flags (flags still work)
- **Pre-configured environments**: Use `validators/{testnet,mainnet,devnet}/` for easier setup
- **Directory agnostic**: Scripts work from anywhere, no need to `cd` to project root

## Documentation

### 🚀 Getting Started
- **[Quick Start Guide](docs/QUICK-START.md)** - Complete setup walkthrough for new users
- **[Migration Guide](docs/MIGRATION.md)** - Upgrading from older valops versions
- **[Identity Generation Guide](docs/IDENTITY-GENERATION.md)** - Secure offline identity creation and deployment
- **[Operations Guide](docs/OPERATIONS.md)** - Day-to-day validator management and maintenance

### 📊 Monitoring & Operations  
- **[Monitoring Guide](docs/MONITORING.md)** - Comprehensive monitoring, alerting, and observability
- **[API Reference](docs/API.md)** - Complete reference for `lib.sh` utility functions

### 🏗️ Architecture & Development
- **[Architecture Guide](docs/ARCHITECTURE.md)** - Detailed development architecture and workflow
- **[Security Guide](docs/SECURITY.md)** - Security model, key isolation, and threat analysis  
- **[Development Guide](docs/DEVELOPMENT.md)** - Testing, debugging, and contribution workflow

## Quick Links

- **New to validators?** → Start with [Quick Start Guide](docs/QUICK-START.md)
- **Need identity setup?** → See [Identity Generation Guide](docs/IDENTITY-GENERATION.md)
- **Need monitoring?** → See [Monitoring Guide](docs/MONITORING.md)
