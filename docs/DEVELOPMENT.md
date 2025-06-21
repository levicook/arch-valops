# Development Guide

This guide covers testing, debugging, development best practices, and contribution workflow for the valops toolkit.

## Testing & Development Workflow

### Interactive Function Testing

The source-friendly design enables comprehensive testing without affecting production:

```bash
# 1. Source the library for interactive use
source common.sh

# 2. Test individual functions safely
create_user "dev-test"
deploy_validator_operator "dev-test"

# 3. Verify deployment
sudo -u dev-test ls -la /home/dev-test/
cat /etc/logrotate.d/validator-dev-test

# 4. Test operational scripts
sudo -u dev-test /home/dev-test/run-validator &
sudo -u dev-test /home/dev-test/halt-validator

# 5. Clean up test resources
clobber_validator_operator "dev-test"
clobber_user "dev-test"
```

### Development Best Practices

#### Building Binaries in dev-env

```bash
# Connect to development VM
ssh dev-env

# Update and build latest
cd arch-network
git pull origin main
make all

# Verify binaries
ls -la target/release/{arch-cli,validator}

# See all available build targets
make help
```

#### Testing Binary Sync

```bash
# On bare metal - test sync process
./sync-bins

# Verify installation
which arch-cli validator
arch-cli --version
```

#### Validating Environment Setup

```bash
# Test complete deployment
./env-init

# Verify all components
sudo -u testnet-validator ls -la /home/testnet-validator/
cat /etc/logrotate.d/validator-testnet-validator
sudo logrotate -d /etc/logrotate.d/validator-testnet-validator
```

## Debugging Production Issues

### Log Analysis

```bash
# Monitor real-time operations
tail -f /home/testnet-validator/logs/validator.log

# Search specific events
grep "run-validator:" /home/testnet-validator/logs/validator.log | tail -10
grep "halt-validator:" /home/testnet-validator/logs/validator.log | tail -5

# Check startup configurations
grep "Configuration:" /home/testnet-validator/logs/validator.log | tail -1
```

### Process Management

```bash
# Check validator status
ps aux | grep validator
sudo -u testnet-validator pgrep -f "arch-cli validator-start"

# Test shutdown behavior
sudo -u testnet-validator /home/testnet-validator/halt-validator
```

### Environment Validation

```bash
# Source common.sh for diagnostic functions
source common.sh

# Check user and directory state
id testnet-validator
sudo -u testnet-validator ls -la /home/testnet-validator/

# Verify binary installation
which arch-cli validator
ls -la /usr/local/bin/{arch-cli,validator}

# Test network connectivity
curl -s https://titan-public-http.test.arch.network | head -5
```

## Interactive Development

### Using common.sh for Development

```bash
# Interactive testing of individual functions
ubuntu@server:~/valops$ source common.sh

ubuntu@server:~/valops$ create_user "test-validator"
common: Creating test-validator user...
common: ✓ Created test-validator user

ubuntu@server:~/valops$ deploy_validator_operator "test-validator"
common: ✓ Validator directories already exist for test-validator
common: Deploying validator scripts for test-validator...
common: ✓ Deployed run-validator script for test-validator
common: ✓ Deployed halt-validator script for test-validator
common: ✓ Deployed logrotate config for test-validator
common: ✓ Deployed validator operator for test-validator

ubuntu@server:~/valops$ clobber_user "test-validator"  # Cleanup
common: Removing test-validator user...
common: ✓ Removed test-validator user
```

### Maintenance Benefits

- **Function-level testing**: Test individual operations without full workflow
- **Debugging**: Inspect state between function calls
- **Development**: Iterate on functions interactively
- **Validation**: Verify idempotency by running functions multiple times
- **Troubleshooting**: Diagnose issues by stepping through operations manually

## Troubleshooting Guide

### Common Issues and Solutions

#### `env-init` fails with "run-validator script not found"
**Problem**: Resource scripts missing
**Solution**: Ensure `resources/run-validator` exists in the project directory

#### `sync-bins` fails with connection errors
**Problem**: Cannot connect to development VM
**Solutions**:
- Verify `dev-env` VM is running: `multipass list`
- Check SSH connectivity: `multipass exec dev-env -- echo "test"`
- Verify VM IP: `multipass info dev-env | grep IPv4`

#### Validator fails to start
**Problem**: Startup issues
**Solutions**:
- Check logs: `tail -f /home/testnet-validator/logs/validator.log`
- Verify binaries: `which arch-cli && which validator`
- Check environment: `sudo -u testnet-validator ls -la /home/testnet-validator/`
- Verify network connectivity: `curl -s https://titan-public-http.test.arch.network`

#### Validator won't stop
**Problem**: Shutdown issues
**Solutions**:
- Check process status: `ps aux | grep validator`
- Try manual halt: `sudo -u testnet-validator /home/testnet-validator/halt-validator`
- Check logs for shutdown details: `grep "halt-validator:" /home/testnet-validator/logs/validator.log`

#### Log rotation not working
**Problem**: Logs not rotating properly
**Solutions**:
- Check configuration: `cat /etc/logrotate.d/validator-testnet-validator`
- Test manually: `sudo logrotate -d /etc/logrotate.d/validator-testnet-validator`
- Verify permissions: `ls -la /home/testnet-validator/logs/`

## Development Environment Setup

### Prerequisites

```bash
# Install development dependencies
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl wget git tmux htop nethogs jq build-essential

# Install multipass
sudo snap install multipass

# Install Rust (in dev-env VM)
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
source ~/.cargo/env
rustup install 1.82.0 && rustup default 1.82.0
```

### Development VM Setup

```bash
# Create and configure development VM
multipass launch --name dev-env --memory 4G --disk 20G --cpus 2
multipass exec dev-env -- sudo apt update
multipass exec dev-env -- sudo apt install -y build-essential git curl

# Configure SSH access
multipass exec dev-env -- mkdir -p ~/.ssh
multipass exec dev-env -- chmod 700 ~/.ssh
# Add your SSH public key to dev-env VM
```

### Project Setup

```bash
# Clone repository
git clone https://github.com/your-org/valops.git
cd valops

# Make scripts executable
chmod +x env-init sync-bins validator-dashboard

# Initialize environment
./env-init
```

## Testing Strategies

### Unit Testing (Individual Functions)

```bash
# Test user management functions
source common.sh
create_user "test-user"
deploy_validator_operator "test-user"
clobber_validator_operator "test-user"
clobber_user "test-user"
```

### Integration Testing (Full Workflow)

```bash
# Test complete deployment workflow
./env-init
./sync-bins

# Test validator operations
sudo -u testnet-validator /home/testnet-validator/run-validator &
sleep 10
sudo -u testnet-validator /home/testnet-validator/halt-validator

# Test monitoring
VALIDATOR_USER=testnet-validator ./validator-dashboard
```

### System Testing (Production Scenarios)

```bash
# Test with different validator users
./env-init
deploy_validator_operator "mainnet-validator"
VALIDATOR_USER=mainnet-validator ./validator-dashboard

# Test error conditions
# Simulate various failure modes and verify recovery
```

## Contribution Guidelines

### Code Standards

#### Shell Script Best Practices

```bash
# Always use strict mode
set -euo pipefail

# Source common utilities
source "$(dirname "$0")/common.sh"

# Use consistent output formatting
log_echo() {
    echo "script-name: $@"
}

# Implement idempotency
if [ ! -f "$target_file" ]; then
    create_file "$target_file"
fi
```

#### Function Design Principles

1. **Single Responsibility**: Each function does one thing well
2. **Idempotency**: Safe to run multiple times
3. **Error Handling**: Fail fast with clear messages
4. **Consistent Interface**: Predictable parameters and return values
5. **Documentation**: Clear comments and usage examples

### Testing Requirements

#### Before Submitting Changes

1. **Test on clean system**: Verify functionality on fresh installation
2. **Test idempotency**: Run operations multiple times
3. **Test error conditions**: Verify graceful handling of failures
4. **Test cleanup**: Ensure resources are properly removed
5. **Update documentation**: Keep all guides current

#### Code Review Checklist

- [ ] Follows shell script best practices
- [ ] Implements proper error handling
- [ ] Maintains idempotency
- [ ] Includes appropriate logging
- [ ] Updates relevant documentation
- [ ] Tested on clean system
- [ ] Verified security implications

### Development Workflow

#### Making Changes

```bash
# 1. Create feature branch
git checkout -b feature/new-functionality

# 2. Make changes
# Edit relevant files...

# 3. Test changes
./env-init  # Test environment setup
./sync-bins  # Test binary synchronization
# Test specific functionality...

# 4. Update documentation
# Update relevant .md files...

# 5. Commit changes
git add .
git commit -m "feat: add new functionality"

# 6. Push and create PR
git push origin feature/new-functionality
```

#### Release Process

1. **Version Planning**: Determine semantic version increment
2. **Testing**: Comprehensive testing on multiple environments
3. **Documentation**: Update all relevant documentation
4. **Changelog**: Document changes and breaking changes
5. **Tagging**: Create git tags for releases
6. **Deployment**: Update production deployments

### Documentation Standards

#### Required Documentation

- **README.md**: Overview and quick start
- **docs/QUICK-START.md**: Detailed setup guide
- **docs/OPERATIONS.md**: Operational procedures
- **docs/MONITORING.md**: Monitoring and observability
- **docs/ARCHITECTURE.md**: System architecture
- **docs/SECURITY.md**: Security model and procedures
- **docs/DEVELOPMENT.md**: Development and contribution guide
- **docs/API.md**: Function reference

#### Documentation Guidelines

1. **User-Focused**: Write for the intended audience
2. **Step-by-Step**: Provide clear, actionable instructions
3. **Examples**: Include practical code examples
4. **Troubleshooting**: Address common issues
5. **Cross-References**: Link related sections
6. **Keep Current**: Update with code changes

## Performance Optimization

### Profiling and Monitoring

```bash
# Monitor script performance
time ./env-init
time ./sync-bins

# Monitor resource usage
htop  # System resources
iotop  # Disk I/O
nethogs  # Network usage

# Profile specific functions
source common.sh
time get_validator_pid "testnet-validator"
time get_block_height
```

### Optimization Strategies

1. **Minimize External Calls**: Cache results when possible
2. **Parallel Operations**: Use background processes for independent tasks
3. **Efficient Algorithms**: Choose appropriate data structures and algorithms
4. **Resource Management**: Clean up temporary files and processes
5. **Network Optimization**: Minimize network calls and use efficient protocols

## Maintenance Procedures

### Regular Maintenance Tasks

#### Weekly Tasks

```bash
# Update system packages
sudo apt update && sudo apt upgrade -y

# Check for security updates
sudo unattended-upgrade --dry-run

# Review logs
grep ERROR /home/testnet-validator/logs/validator.log* | tail -20
```

#### Monthly Tasks

```bash
# Comprehensive system check
df -h  # Disk usage
free -h  # Memory usage
uptime  # System load

# Update development environment
multipass exec dev-env -- sudo apt update
multipass exec dev-env -- sudo apt upgrade -y

# Review documentation
# Check if any procedures need updating
```

### Disaster Recovery Testing

```bash
# Test backup procedures
./env-init  # Should handle clean deployment
./sync-bins  # Should handle binary recovery

# Test monitoring recovery
VALIDATOR_USER=testnet-validator ./validator-dashboard
# Verify all monitoring functions work
```

This development guide provides the foundation for contributing to and maintaining the valops toolkit while ensuring high quality and security standards. 