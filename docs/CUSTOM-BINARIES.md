# Custom Binary Deployment

🔧 **For**: Users running modified blockchain software  
🎯 **Focus**: Building and deploying custom binaries via isolated VMs

## Overview

This guide covers running **custom/modified versions** of blockchain binaries instead of official releases. Most users should use official releases via the standard setup guides.

**Use custom binaries when:**
- Testing patches or modifications
- Running experimental features
- Using development versions
- Evaluating pre-release code

## Architecture

### Binary Deployment Model
**Hybrid approach**: Support both official releases and custom builds via isolated VMs.

```
Custom Binary Source        Production Environment
┌─────────────────────┐      ┌──────────────────────┐
│ Multipass VM        │      │ Bare Metal Server    │
│ - Build custom      │────▶ │ - Run validators     │
│ - Modified binaries │      │ - Encrypted identity │
│ - Isolated builds   │      │ - Production keys    │
└─────────────────────┘      └──────────────────────┘
```

**Key Benefits**:
- **Flexibility**: Run official releases OR custom builds
- **Security**: Custom build environment isolated from validator keys
- **Performance**: Validators run on bare metal for optimal performance
- **Isolation**: Clear separation between custom builds and runtime environment

### Binary Management System
```bash
# Three specialized sync scripts with dual strategies:
sync-arch-bins     # Arch Network (validator, arch-cli)
sync-bitcoin-bins  # Bitcoin Core (bitcoind, bitcoin-cli)
sync-titan-bins    # Titan (titan binary)

# Two strategies per script:
# Release: Official binaries from GitHub/bitcoincore.org (RECOMMENDED)
# VM: Custom builds from multipass VM (for modified versions)
```

## Prerequisites

```bash
# Install dependencies
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl wget git tmux htop nethogs jq build-essential age direnv

# Install multipass for custom binary builds
sudo snap install multipass

# Setup direnv shell hook
echo 'eval "$(direnv hook bash)"' >> ~/.bashrc && source ~/.bashrc
```

## Custom Build Environment Setup

### Create Build VM
**Note**: Only needed if you want to run custom/modified binaries instead of official releases.

```bash
# Create custom build VM
multipass launch --name dev-env --memory 4G --disk 20G --cpus 2

# Configure VM for building
multipass exec dev-env -- sudo apt update
multipass exec dev-env -- sudo apt install -y build-essential git curl

# Install Rust in VM
multipass exec dev-env -- bash -c 'curl --proto "=https" --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y'
multipass exec dev-env -- bash -c 'source ~/.cargo/env && rustup install 1.82.0 && rustup default 1.82.0'
```

### Clone Source Repositories
```bash
# Clone source repositories in VM
multipass exec dev-env -- git clone https://github.com/Arch-Network/arch-node.git /home/ubuntu/Arch-Network/arch-network
multipass exec dev-env -- git clone https://github.com/SaturnBTC/Titan.git /home/ubuntu/SaturnBTC/Titan

# Verify VM setup
multipass exec dev-env -- ls -la /home/ubuntu/
```

### Project Setup
```bash
# Clone valops project (if not already done)
git clone https://github.com/levicook/arch-valops.git ~/valops
cd ~/valops && direnv allow

# Setup age encryption keys
setup-age-keys

# Test binary sync from VM
SYNC_STRATEGY_ARCH=vm sync-arch-bins
SYNC_STRATEGY_BITCOIN=vm sync-bitcoin-bins
sync-titan-bins
```

## Building Custom Binaries

### Arch Network
```bash
# Build Arch Network in VM
multipass exec dev-env -- bash -c 'cd /home/ubuntu/Arch-Network/arch-network && cargo build --release'

# Sync to bare metal for testing
SYNC_STRATEGY_ARCH=vm sync-arch-bins

# Verify installation
which validator && validator --version
```

### Titan
```bash
# Build Titan in VM
multipass exec dev-env -- bash -c 'cd /home/ubuntu/SaturnBTC/Titan && cargo build --release'

# Sync to bare metal
sync-titan-bins

# Verify installation
which titan && titan --version
```

### Bitcoin Core
**Note**: Bitcoin builds take significant time and resources. Consider using official releases unless you need specific modifications.

```bash
# Bitcoin requires additional setup in VM
multipass exec dev-env -- sudo apt install -y make libtool autotools-dev automake pkg-config bsdmainutils python3

# Clone and build (this takes 1-2 hours)
multipass exec dev-env -- git clone https://github.com/bitcoin/bitcoin.git /home/ubuntu/bitcoin
multipass exec dev-env -- bash -c 'cd /home/ubuntu/bitcoin && ./autogen.sh && ./configure --disable-tests --disable-gui-tests && make -j$(nproc)'

# Sync to bare metal
SYNC_STRATEGY_BITCOIN=vm sync-bitcoin-bins
```

## Testing Custom Binaries

### Basic Functionality Test
```bash
# Test complete workflow with custom binaries
setup-age-keys

# Use existing identity for testing (if available)
VALIDATOR_ENCRYPTED_IDENTITY_KEY=~/.valops/age/identity-backup-*.age validator-init

# Start with custom binaries
validator-up

# Monitor for issues
validator-dashboard
```

### Binary Verification
```bash
# Verify custom binaries are being used
which validator && validator --version
which bitcoind && bitcoind --version
which titan && titan --version

# Check binary modification times (should be recent if custom built)
ls -la /usr/local/bin/validator
ls -la /usr/local/bin/bitcoind
ls -la /usr/local/bin/titan
```

## Troubleshooting

### VM Issues
```bash
# Check VM status
multipass list

# Restart VM if needed
multipass restart dev-env

# Test VM connectivity
multipass exec dev-env -- echo "test"
```

### Build Issues
```bash
# Check build logs in VM
multipass exec dev-env -- bash -c 'cd /home/ubuntu/Arch-Network/arch-network && cargo build --release 2>&1 | tail -20'

# Check disk space in VM
multipass exec dev-env -- df -h

# Clean and rebuild if needed
multipass exec dev-env -- bash -c 'cd /home/ubuntu/Arch-Network/arch-network && cargo clean && cargo build --release'
```

### Sync Issues
```bash
# Debug sync connectivity
SYNC_STRATEGY_ARCH=vm sync-arch-bins  # Test VM strategy
ARCH_VERSION=v0.5.3 sync-arch-bins    # Compare with release strategy

# Check binary paths and permissions
ls -la /usr/local/bin/validator
ls -la /usr/local/bin/bitcoind
ls -la /usr/local/bin/titan
```

## Advanced Custom Build Scenarios

### Multi-VM Setup
```bash
# Create specialized VMs for different projects
multipass launch --name arch-dev --memory 8G ubuntu:22.04
multipass launch --name bitcoin-dev --memory 4G ubuntu:22.04

# Configure sync scripts for different VMs
VM_NAME=arch-dev SYNC_STRATEGY_ARCH=vm sync-arch-bins
VM_NAME=bitcoin-dev SYNC_STRATEGY_BITCOIN=vm sync-bitcoin-bins
```

### Custom Validator Environments
```bash
# Create custom environment for testing
mkdir -p validators/custom
cat > validators/custom/.envrc << 'EOF'
# Custom validator environment for testing
export VALIDATOR_USER=custom-validator
export ARCH_NETWORK_MODE=testnet
export SYNC_STRATEGY_ARCH=vm
export SYNC_STRATEGY_BITCOIN=vm
EOF

# Use custom environment
cd validators/custom && direnv allow
validator-init && validator-up
```

## Security Considerations

### Build Environment Isolation
- **VM isolation**: Build environment cannot access validator keys
- **Source verification**: Only clone from trusted repositories
- **Binary verification**: Verify built binaries match expected sources

### Production Usage
- **Test thoroughly**: Custom binaries should be extensively tested
- **Backup strategy**: Ensure backups work with custom software
- **Rollback plan**: Keep official binaries available for quick rollback

## Best Practices

1. **Use official releases** unless you specifically need custom features
2. **Test custom binaries** thoroughly in testnet before mainnet
3. **Document modifications** clearly for future reference
4. **Keep VM updated** regularly for security
5. **Monitor resource usage** during builds (especially Bitcoin)
6. **Backup your work** - VM images and source modifications

## Support

- **Official binaries**: Use standard setup guides (QUICK-START.md, OPERATIONS.md)
- **Custom build issues**: See project-specific documentation (Arch Network, Bitcoin Core, Titan)
- **Valops integration**: See DEVELOPMENT.md for script development

---

**Most users should use official releases.** Only use custom binaries if you need specific modifications or are contributing to blockchain development. 