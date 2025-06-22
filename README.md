# Arch Network Validator Operations (valops)

🏗️ **Infrastructure-as-Code toolkit for secure Arch Network validator operations with hybrid development architecture and comprehensive monitoring dashboard**

## Key Features

- 🔒 **Security-First Architecture** - Complete isolation of signing keys from development infrastructure
- 📊 **Real-Time Monitoring** - Comprehensive tmux dashboard with process, network, and log monitoring  
- 🚀 **Hybrid Development Model** - Build in VMs, deploy on bare metal for optimal performance
- 🔄 **Infrastructure-as-Code** - Idempotent, version-controlled validator operations
- 🌐 **Zero-Trust Deployment** - SSH tunneling with agent forwarding, no credentials stored on servers

## Quick Start

```bash
# 1. Assess host security (recommended first step)
./check-env

# 2. Setup age encryption keys (one-time)
./setup-age-keys

# 3. Sync latest binaries from dev VM
./sync-bins

# 4. Initialize validator with encrypted identity (one-time)
./validator-init --encrypted-identity-key validator-identity.age --network testnet --user testnet-validator

# 5. Start validator
./validator-up --user testnet-validator

# 6. Monitor with comprehensive dashboard
VALIDATOR_USER=testnet-validator ./validator-dashboard

# 7. Stop validator
./validator-down --user testnet-validator
```

## Architecture at a Glance

This toolkit implements a **hybrid development model** that separates build and runtime environments:

- **Development VM**: Build binaries in isolated multipass `dev-env` VM
- **Bare Metal Deployment**: Run validators on bare metal for optimal performance
- **SSH Tunneling**: Secure development workflow with credential isolation
- **Key Separation**: Development keys completely isolated from validator signing keys

The architecture ensures that even complete compromise of development infrastructure cannot access validator funds or signing keys.

## Documentation

### 🚀 Getting Started
- **[Quick Start Guide](docs/QUICK-START.md)** - Complete setup walkthrough for new users
- **[Identity Generation Guide](docs/IDENTITY-GENERATION.md)** - Secure offline identity creation and deployment
- **[Operations Guide](docs/OPERATIONS.md)** - Day-to-day validator management and maintenance

### 📊 Monitoring & Operations  
- **[Monitoring Guide](docs/MONITORING.md)** - Comprehensive monitoring, alerting, and observability
- **[API Reference](docs/API.md)** - Complete reference for `lib.sh` utility functions

### 🏗️ Architecture & Development
- **[Architecture Guide](docs/ARCHITECTURE.md)** - Detailed development architecture and workflow
- **[Security Guide](docs/SECURITY.md)** - Security model, key isolation, and threat analysis  
- **[Development Guide](docs/DEVELOPMENT.md)** - Testing, debugging, and contribution workflow

## Monitoring Dashboard

The `validator-dashboard` provides real-time observability through a sophisticated tmux interface:

```bash
# Start comprehensive monitoring
VALIDATOR_USER=testnet-validator ./validator-dashboard
```

**Dashboard Features:**
- **Status Monitoring**: Real-time validator health, network connectivity, data metrics
- **Live Logs**: Streaming validator activity with error highlighting
- **System Resources**: CPU, memory, and network usage monitoring
- **Operational Guidance**: Built-in help and troubleshooting commands

**Navigation:**
- `Ctrl+b + n/p`: Switch windows | `Ctrl+b + arrows`: Switch panes | `Ctrl+b + d`: Detach

## Project Structure

```
valops/
├── check-env                         # Host security assessment tool
├── setup-age-keys                    # Age encryption keypair setup
├── validator-init                    # One-time validator initialization
├── validator-up                      # Start validator process
├── validator-down                    # Stop validator process
├── sync-bins                         # Binary synchronization from dev VM  
├── lib.sh                            # Shared utilities library
├── validator-dashboard               # Comprehensive monitoring dashboard
├── validator-dashboard-helpers/      # Modular dashboard components
├── resources/                        # Deployable validator scripts
│   ├── run-validator                 # Validator startup script
│   └── halt-validator                # Validator shutdown script
└── docs/                             # Detailed documentation
    ├── QUICK-START.md                # Complete setup walkthrough
    ├── IDENTITY-GENERATION.md        # Secure identity creation workflow
    ├── MONITORING.md                 # Monitoring and observability
    ├── OPERATIONS.md                 # Operational procedures  
    ├── ARCHITECTURE.md               # Development architecture
    ├── SECURITY.md                   # Security model and analysis
    ├── DEVELOPMENT.md                # Testing and development workflow
    └── API.md                        # Utility function reference
```

## Core Operations

### Security Assessment
```bash
./check-env   # Comprehensive host security assessment (run first)
```

### Environment Setup
```bash
./setup-age-keys  # Setup age encryption keys (one-time)
./sync-bins       # Sync latest binaries from development VM
```

### Validator Lifecycle
```bash
# Initialize validator with encrypted identity (one-time)
./validator-init --encrypted-identity-key validator-identity.age --network testnet --user testnet-validator

# Start validator
./validator-up --user testnet-validator

# Stop validator (graceful shutdown)  
./validator-down --user testnet-validator

# Complete removal (stop + remove all validator data)
./validator-down --clobber --user testnet-validator

# Monitor real-time
VALIDATOR_USER=testnet-validator ./validator-dashboard
```

## Security Model

This toolkit implements **defense in depth** with multiple isolation layers:

1. **Development Keys** (SSH, GPG, GitHub) - Isolated to developer laptop via agent forwarding
2. **Infrastructure Keys** - Minimal scope server access keys  
3. **Validator Signing Keys** - Completely separate, hardware-secured, never touched by this toolkit

**Security Guarantee**: Even total compromise of valops infrastructure cannot access validator funds.

## Quick Links

- **New to validators?** → Start with [Quick Start Guide](docs/QUICK-START.md)
- **Need identity setup?** → See [Identity Generation Guide](docs/IDENTITY-GENERATION.md)
- **Need monitoring?** → See [Monitoring Guide](docs/MONITORING.md)  
- **Troubleshooting?** → Check [Operations Guide](docs/OPERATIONS.md)
- **Want to contribute?** → Read [Development Guide](docs/DEVELOPMENT.md)
- **Security questions?** → Review [Security Guide](docs/SECURITY.md)

---

**Production Ready** | **Security First** | **Monitoring Focused** | **Developer Friendly**
