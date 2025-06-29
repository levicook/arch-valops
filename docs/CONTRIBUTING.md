# Contributing Guide

👩‍💻 **For**: Contributors wanting to understand and modify the codebase
🎯 **Focus**: System architecture, development workflow, testing procedures

## Architecture Overview

### Development Model
**Hybrid approach**: Build in VMs, deploy on bare metal for optimal security and performance.

```
Development Environment      Production Environment
┌─────────────────────┐      ┌──────────────────────┐
│ Multipass VM        │      │ Bare Metal Server    │
│ - Build binaries    │────▶ │ - Run validators     │
│ - Test changes      │      │ - Encrypted identity │
│ - Development keys  │      │ - Production keys    │
└─────────────────────┘      └──────────────────────┘
```

**Key Benefits**:
- **Security**: Development compromise cannot access validator funds
- **Performance**: Validators run on bare metal for optimal performance
- **Isolation**: Clear separation between build and runtime environments

### Core Components

#### Binary Management System
```bash
# Three specialized sync scripts with dual strategies:
sync-arch-bins     # Arch Network (validator, arch-cli)
sync-bitcoin-bins  # Bitcoin Core (bitcoind, bitcoin-cli)
sync-titan-bins    # Titan (titan binary)

# Two strategies per script:
# Release: Official binaries from GitHub/bitcoincore.org
# VM: Development builds from multipass VM
```

#### Identity Management
```bash
# Encrypted identity lifecycle:
setup-age-keys               # Create age keypair
validator --generate-peer-id # Generate identity (offline)
age -r $PUB_KEY              # Encrypt identity
validator-init               # Deploy encrypted identity
backup-identities            # Backup all identities
```

#### Environment Management
```bash
# Pre-configured validator environments:
validators/testnet/.envrc   # Testnet defaults
validators/mainnet/.envrc   # Mainnet defaults
validators/devnet/.envrc    # Development defaults

# Automatic environment loading via direnv
cd validators/testnet && direnv allow
validator-up  # Uses testnet configuration automatically
```

### Script Architecture

#### Environment Variable Interface
All scripts use **environment variables first** with backward-compatible flags:

```bash
# ✅ Recommended: Environment variables
VALIDATOR_USER=testnet-validator validator-up

# ✅ Also works: Traditional flags
validator-up --user testnet-validator

# ✅ Best: Pre-configured environments
cd validators/testnet && validator-up
```

#### Shared Libraries
- **`lib.sh`**: Core utilities (user management, validator inspection)
- **`sync-lib.sh`**: Binary sync utilities (VM sync, GitHub downloads)
- **`validator-lib.sh`**: Validator-specific operations

#### Idempotency Design
All operations are safe to repeat:
```bash
validator-init  # Safe to re-run (updates configs)
validator-up    # Safe to re-run (starts if stopped)
sync-arch-bins  # Safe to re-run (only updates if changed)
```

## Development Environment Setup

### Prerequisites
```bash
# Install development dependencies
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl wget git tmux htop nethogs jq build-essential age direnv

# Install multipass for VM development
sudo snap install multipass

# Setup direnv shell hook
echo 'eval "$(direnv hook bash)"' >> ~/.bashrc && source ~/.bashrc
```

### Development VM Setup
```bash
# Create development VM
multipass launch --name dev-env --memory 4G --disk 20G --cpus 2

# Configure VM for development
multipass exec dev-env -- sudo apt update
multipass exec dev-env -- sudo apt install -y build-essential git curl

# Install Rust in VM
multipass exec dev-env -- bash -c 'curl --proto "=https" --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y'
multipass exec dev-env -- bash -c 'source ~/.cargo/env && rustup install 1.82.0 && rustup default 1.82.0'

# Clone projects in VM
multipass exec dev-env -- git clone https://github.com/Arch-Network/arch-node.git /home/ubuntu/Arch-Network/arch-network
multipass exec dev-env -- git clone https://github.com/SaturnBTC/Titan.git /home/ubuntu/SaturnBTC/Titan
```

### Project Setup
```bash
# Clone valops project
git clone https://github.com/levicook/arch-valops.git ~/valops
cd ~/valops && direnv allow

# Setup age encryption keys
setup-age-keys

# Test binary sync from VM
SYNC_STRATEGY_ARCH=vm sync-arch-bins
SYNC_STRATEGY_BITCOIN=vm sync-bitcoin-bins
sync-titan-bins
```

## Development Workflow

### Building Binaries
```bash
# Build Arch Network in VM
multipass exec dev-env -- bash -c 'cd /home/ubuntu/Arch-Network/arch-network && cargo build --release'

# Build Titan in VM
multipass exec dev-env -- bash -c 'cd /home/ubuntu/SaturnBTC/Titan && cargo build --release'

# Sync to bare metal for testing
SYNC_STRATEGY_ARCH=vm sync-arch-bins
sync-titan-bins
```

### Testing Changes
```bash
# Test complete workflow
setup-age-keys
VALIDATOR_ENCRYPTED_IDENTITY_KEY=test-identity.age validator-init
validator-up
validator-dashboard  # Monitor for issues
validator-down
```

### Making Code Changes

#### Script Development
```bash
# Make changes to scripts in scripts/ directory
vim scripts/validator-up

# Test changes
./scripts/validator-up --user testnet-validator

# Test idempotency
./scripts/validator-up --user testnet-validator  # Should be safe to repeat
```

#### Function Development
```bash
# Edit shared functions
vim scripts/lib.sh

# Interactive testing
source scripts/lib.sh
create_user "test-user"           # Test function
is_validator_running "test-user"  # Test another function
clobber_user "test-user"          # Cleanup
```

#### Binary Sync Development
```bash
# Test binary sync scripts
vim scripts/sync-arch-bins

# Test both strategies
ARCH_VERSION=v0.5.3 sync-arch-bins   # Release strategy
SYNC_STRATEGY_ARCH=vm sync-arch-bins # VM strategy
```

## Testing Framework

### Unit Testing (Function Level)
```bash
#!/bin/bash
# test-functions.sh - Test individual functions

source scripts/lib.sh

# Test user management
echo "Testing user management..."
create_user "test-user"
if id "test-user" >/dev/null 2>&1; then
    echo "✓ create_user works"
else
    echo "✗ create_user failed"
fi

# Cleanup
clobber_user "test-user"
```

### Integration Testing (Full Workflow)
```bash
#!/bin/bash
# test-integration.sh - Test complete workflows

set -euo pipefail

echo "Testing complete validator lifecycle..."

# Setup
setup-age-keys
VALIDATOR_ENCRYPTED_IDENTITY_KEY=test-identity.age validator-init

# Test operations
validator-up
sleep 10

# Verify running
if ps aux | grep -q validator; then
    echo "✓ Validator started successfully"
else
    echo "✗ Validator failed to start"
    exit 1
fi

# Cleanup
validator-down --clobber
```

### Performance Testing
```bash
#!/bin/bash
# test-performance.sh - Performance benchmarks

echo "Testing binary sync performance..."
time SYNC_STRATEGY_ARCH=vm sync-arch-bins
time SYNC_STRATEGY_BITCOIN=vm sync-bitcoin-bins
time sync-titan-bins

echo "Testing validator startup time..."
time validator-up

echo "Testing dashboard startup..."
time validator-dashboard --test-mode
```

## Code Standards

### Shell Script Best Practices
```bash
# Always use strict mode
set -euo pipefail

# Source dependencies properly
source "$(dirname "$0")/lib.sh"

# Use consistent output formatting
log_echo() {
    echo "script-name: $@"
}

# Implement proper error handling
if ! command -v validator >/dev/null 2>&1; then
    log_echo "✗ validator binary not found"
    exit 1
fi
```

### Function Design Principles
1. **Single Responsibility**: Each function does one thing well
2. **Idempotency**: Safe to run multiple times
3. **Error Handling**: Fail fast with clear messages
4. **Consistent Interface**: Predictable parameters and return values
5. **Documentation**: Clear comments explaining behavior

### Environment Variable Conventions
```bash
# Primary interface (recommended)
VALIDATOR_USER="testnet-validator"
ARCH_VERSION="v0.5.3"
SYNC_STRATEGY_ARCH="release"

# Flag fallbacks (backward compatibility)
validator-up --user "$VALIDATOR_USER"
sync-arch-bins --version "$ARCH_VERSION"
```

## Debugging and Troubleshooting

### Interactive Development
```bash
# Use lib.sh functions interactively
source scripts/lib.sh
export VALIDATOR_USER=testnet-validator

# Debug validator status
echo "Running: $(is_validator_running "$VALIDATOR_USER" && echo yes || echo no)"
echo "PID: $(get_validator_pid "$VALIDATOR_USER")"
echo "Block height: $(get_block_height)"
echo "Error count: $(get_error_count "$VALIDATOR_USER")"
```

### Debugging Binary Sync
```bash
# Test VM connectivity
multipass list
multipass exec dev-env -- echo "test"

# Debug sync issues
SYNC_STRATEGY_ARCH=vm sync-arch-bins  # Test VM strategy
ARCH_VERSION=v0.5.3 sync-arch-bins    # Test release strategy

# Check binary paths
ls -la /usr/local/bin/validator
```

### Log Analysis
```bash
# Monitor validator logs
tail -f /home/testnet-validator/logs/validator.log

# Search for specific events
grep "validator-up:" /home/testnet-validator/logs/validator.log | tail -10
grep ERROR /home/testnet-validator/logs/validator.log | tail -10

# Check script output
grep "sync-arch-bins:" /home/testnet-validator/logs/validator.log
```

## Release Process

### Version Management
```bash
# Tag releases
git tag -a v1.2.3 -m "Release version 1.2.3"
git push origin v1.2.3

# Update version references in docs
# Update binary version defaults in environment files
```

### Pre-Release Testing
```bash
# Test on clean system
multipass launch --name test-system ubuntu:22.04
# Install and test complete setup process

# Test upgrade scenarios
# Test migration from previous versions
# Verify backward compatibility
```

### Documentation Updates
- Update QUICK-START.md with any new prerequisites
- Update OPERATIONS.md with new operational procedures
- Update SECURITY.md with security implications
- Update version references throughout documentation

## Contributing Checklist

### Before Submitting Changes
- [ ] **Test on clean system**: Verify functionality on fresh installation
- [ ] **Test idempotency**: Run operations multiple times
- [ ] **Test error conditions**: Verify graceful handling of failures
- [ ] **Test cleanup**: Ensure resources are properly removed
- [ ] **Update documentation**: Keep all guides current
- [ ] **Follow code standards**: Implement proper error handling and logging
- [ ] **Test backward compatibility**: Ensure existing workflows still work

### Pull Request Guidelines
1. **Clear description**: Explain what changes and why
2. **Test results**: Include test output and verification steps
3. **Documentation updates**: Update relevant docs
4. **Breaking changes**: Clearly mark and provide migration path
5. **Security review**: Consider security implications

## Advanced Development

### Custom Validator Environments
```bash
# Create new environment
mkdir -p validators/custom
cat > validators/custom/.envrc << 'EOF'
# Custom validator environment
export VALIDATOR_USER=custom-validator
export ARCH_NETWORK_MODE=testnet
export ARCH_VERSION=v0.5.3
export BITCOIN_VERSION=29.0
EOF

# Test new environment
cd validators/custom && direnv allow
validator-init && validator-up
```

### Multi-VM Development
```bash
# Create specialized VMs
multipass launch --name arch-dev --memory 8G ubuntu:22.04
multipass launch --name bitcoin-dev --memory 4G ubuntu:22.04

# Configure sync scripts for different VMs
VM_NAME=arch-dev SYNC_STRATEGY_ARCH=vm sync-arch-bins
VM_NAME=bitcoin-dev SYNC_STRATEGY_BITCOIN=vm sync-bitcoin-bins
```

### Automation Integration
```bash
# CI/CD pipeline example
#!/bin/bash
# .github/workflows/test.yml equivalent

# Setup
setup-age-keys

# Test binary sync
SYNC_STRATEGY_ARCH=vm sync-arch-bins || exit 1

# Test validator lifecycle
VALIDATOR_ENCRYPTED_IDENTITY_KEY=ci-identity.age validator-init || exit 1
validator-up || exit 1
sleep 30
validator-down || exit 1
```

---

**New to contributing?** → Start with Development Environment Setup | **Need architecture details?** → See Architecture Overview | **Ready to code?** → Follow Development Workflow