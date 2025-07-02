# Development Guide

👩‍💻 **For**: Contributors wanting to understand and modify the valops codebase  
🎯 **Focus**: System architecture, development workflow, testing procedures, contributing guidelines

## System Architecture

### Script Architecture

All valops scripts follow consistent architectural patterns for reliability and maintainability.

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

### Infrastructure Management Pattern

Scripts follow the **declare→ensure→start→verify** pattern:

```bash
# 1. Declare what should exist
declare_validator_user "testnet-validator"
declare_validator_configs "/home/testnet-validator"

# 2. Ensure infrastructure exists
ensure_user_exists
ensure_configs_deployed

# 3. Start processes (delegated to systemd)
systemctl start arch-validator@testnet-validator

# 4. Verify results
verify_validator_running
verify_sync_status
```

### Process Management Integration

**Core principle**: Scripts manage infrastructure, systemd manages processes.

```bash
# ❌ Scripts should NOT do process management
pkill validator
nohup validator &
./run-validator

# ✅ Scripts should delegate to systemd  
systemctl start arch-validator@testnet-validator
systemctl stop arch-validator@testnet-validator
systemctl restart arch-validator@testnet-validator
```

## Development Workflow

### Setting Up Development Environment

```bash
# Clone project
git clone https://github.com/levicook/arch-valops.git ~/valops
cd ~/valops && direnv allow

# Setup development dependencies
sudo apt install -y shellcheck

# Test environment
./libs/lib.sh --help
```

### Making Script Changes

#### Script Development
```bash
# Make changes to executable scripts in bin/ directory
vim bin/validator-up

# Test changes in testnet environment
cd validators/testnet
../bin/validator-up --user testnet-validator

# Test idempotency (should be safe to repeat)
../bin/validator-up --user testnet-validator
```

#### Function Development
```bash
# Edit shared functions
vim libs/lib.sh

# Interactive testing
source libs/lib.sh
create_user "test-user"           # Test function
is_validator_running "test-user"  # Test another function
clobber_user "test-user"          # Cleanup
```

#### Binary Sync Development
```bash
# Test binary sync scripts
vim bin/sync-arch-bins

# Test both strategies
ARCH_VERSION=v0.5.3 sync-arch-bins   # Release strategy
SYNC_STRATEGY_ARCH=vm sync-arch-bins # VM strategy
```

## Testing Framework

### Unit Testing (Function Level)
```bash
#!/bin/bash
# test-functions.sh - Test individual functions

source libs/lib.sh

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

# Verify running via systemd
if systemctl is-active --quiet arch-validator@testnet-validator; then
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

### Local Variables in Functions
```bash
# ✅ Always use local for function variables
create_user() {
    local username="$1"
    local home_dir="/home/$username"
    # ... rest of function
}

# ❌ Never use global variables in functions
create_user() {
    username="$1"  # This pollutes global scope
    # ... rest of function
}
```

## Debugging and Troubleshooting

### Interactive Development
```bash
# Use lib.sh functions interactively
source libs/lib.sh
export VALIDATOR_USER=testnet-validator

# Debug validator status via systemd
echo "Service active: $(systemctl is-active arch-validator@testnet-validator 2>/dev/null || echo inactive)"
echo "Block height: $(get_block_height)"
echo "Error count: $(journalctl -u arch-validator@testnet-validator --since "1 hour ago" | grep -c ERROR || echo 0)"
```

### Debugging Binary Sync
```bash
# Test VM connectivity (if using custom binaries)
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
# Monitor validator logs via systemd
journalctl -u arch-validator@testnet-validator -f

# Search for specific events
journalctl -u arch-validator@testnet-validator --since "1 hour ago" | grep ERROR
journalctl -u arch-validator@testnet-validator --since "1 hour ago" | grep "sync-arch-bins"

# Check script execution logs
journalctl --since "1 hour ago" | grep "validator-up:"
```

### Linting and Quality Checks
```bash
# Run shellcheck on all scripts  
find bin/ -name "*.sh" -exec shellcheck {} \;
find libs/ -name "*.sh" -exec shellcheck {} \;

# Check specific script
shellcheck bin/validator-up

# Fix common issues
# - Quote variables: "$var" not $var
# - Use [[ ]] instead of [ ] for tests
# - Declare local variables in functions
```

## Release Process

### Version Management
```bash
# Tag releases with semantic versioning
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

# Test systemd integration
systemctl status arch-validator@testnet-validator
systemctl restart arch-validator@testnet-validator
```

### Documentation Updates
When making changes, update relevant documentation:
- **QUICK-START.md**: New prerequisites or setup steps
- **OPERATIONS.md**: New operational procedures  
- **OBSERVABILITY.md**: New monitoring capabilities
- **SECURITY.md**: Security implications
- **Version references**: Throughout all documentation

## Contributing Guidelines

### Before Submitting Changes
- [ ] **Test on clean system**: Verify functionality on fresh installation
- [ ] **Test idempotency**: Run operations multiple times
- [ ] **Test error conditions**: Verify graceful handling of failures
- [ ] **Test cleanup**: Ensure resources are properly removed
- [ ] **Update documentation**: Keep all guides current
- [ ] **Follow code standards**: Implement proper error handling and logging
- [ ] **Test backward compatibility**: Ensure existing workflows still work
- [ ] **Verify systemd integration**: Scripts should delegate process management

### Pull Request Guidelines
1. **Clear description**: Explain what changes and why
2. **Test results**: Include test output and verification steps
3. **Documentation updates**: Update relevant docs
4. **Breaking changes**: Clearly mark and provide migration path
5. **Security review**: Consider security implications
6. **Architecture compliance**: Follow declare→ensure→start→verify pattern

### Code Review Checklist
- [ ] Functions use `local` variables appropriately
- [ ] Error handling follows consistent patterns
- [ ] Scripts are idempotent (safe to re-run)
- [ ] Process management delegated to systemd
- [ ] Environment variables used for configuration
- [ ] Backward compatibility maintained
- [ ] Documentation updated

## Advanced Development

### Custom Validator Environments
```bash
# Create new environment for development
mkdir -p validators/development
cat > validators/development/.envrc << 'EOF'
# Development validator environment
export VALIDATOR_USER=development-validator
export ARCH_NETWORK_MODE=testnet
export ARCH_VERSION=latest
export BITCOIN_VERSION=29.0
# Use VM binaries for development
export SYNC_STRATEGY_ARCH=vm
export SYNC_STRATEGY_BITCOIN=vm
EOF

# Test new environment
cd validators/development && direnv allow
validator-init && validator-up
```

### Systemd Service Development
```bash
# Test systemd service changes
sudo systemctl daemon-reload
sudo systemctl restart arch-validator@testnet-validator
sudo systemctl status arch-validator@testnet-validator

# Check service configuration
systemctl cat arch-validator@testnet-validator
```

### Multi-Environment Testing
```bash
# Test across multiple environments
for env in testnet mainnet development; do
    echo "Testing $env environment..."
    cd validators/$env
    validator-up && validator-down
    cd ../..
done
```

### Automation Integration
```bash
# CI/CD pipeline example
#!/bin/bash
# .github/workflows/test.yml equivalent

set -euo pipefail

# Setup
setup-age-keys

# Test binary sync
SYNC_STRATEGY_ARCH=release sync-arch-bins || exit 1

# Test validator lifecycle
VALIDATOR_ENCRYPTED_IDENTITY_KEY=ci-identity.age validator-init || exit 1
validator-up || exit 1

# Verify via systemd
if ! systemctl is-active --quiet arch-validator@testnet-validator; then
    echo "✗ Validator failed to start"
    exit 1
fi

# Cleanup
validator-down --clobber || exit 1
```

## Architecture Migration Notes

### From Manual Process Management to Systemd

The valops architecture has migrated from manual process management to systemd delegation:

**Old Pattern (Removed)**:
```bash
# Scripts managed processes directly
pkill validator
nohup validator --config /path/to/config &
```

**New Pattern (Current)**:
```bash
# Scripts declare infrastructure, systemd manages processes
systemctl start arch-validator@testnet-validator
systemctl stop arch-validator@testnet-validator
```

This separation provides:
- **Reliability**: systemd handles process crashes and restarts
- **Consistency**: Standard process management across all services
- **Observability**: Centralized logging via journalctl
- **Maintainability**: Clear separation of concerns

When developing new scripts, always follow the **infrastructure management** pattern and delegate process lifecycle to systemd. 