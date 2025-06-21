# Architecture Guide

This guide explains the development architecture, build system, and workflow patterns used in the valops toolkit.

## Operating Philosophy

This toolkit follows a **hybrid development model** that separates build and runtime environments:

1. **Development VM**: Use multipass `dev-env` VM for building binaries
2. **Bare Metal Deployment**: Deploy and run validators on bare metal for performance
3. **IaC Principles**: All operations are idempotent and version-controlled
4. **Deploy Semantics**: Every run ensures system matches desired state

## Development Architecture

### SSH Tunnel Model

The development workflow uses a sophisticated SSH tunneling approach that enables seamless development from any location:

```
Developer Laptop → Bare Metal Server → Multipass VM
     │                    │                 │
   VS Code            SSH Tunnel        Build Environment
Remote Session    (with agent forward)   (arch-network)
     │                    │                 │
GitHub Access ←──── Agent Forward ────→ Git Operations
```

**SSH Configuration Example:**
```ssh
# ~/.ssh/config
Host bare-metal-server
  HostName your-server.example.com
  User ubuntu
  IdentityFile ~/.ssh/your_key
  AddKeysToAgent yes
  ForwardAgent yes

Host dev-env
  HostName 10.142.17.80  # Multipass VM IP
  User ubuntu
  ProxyJump bare-metal-server
  AddKeysToAgent yes
  ForwardAgent yes
```

**Benefits of this model:**
- **Transparent access**: VS Code Remote connects seamlessly to development VM
- **GitHub integration**: SSH agent forwarding enables git operations without key copying
- **Performance**: Build on VM, deploy on bare metal for optimal performance
- **Security**: No keys stored on intermediate servers
- **Flexibility**: Develop from anywhere with SSH access

### Multipass Development Environment

The `dev-env` VM serves as an isolated build environment:

```bash
# On bare metal server - create development VM
multipass launch --name dev-env --memory 4G --disk 20G --cpus 2

# Install development dependencies in VM
multipass exec dev-env -- sudo apt update
multipass exec dev-env -- sudo apt install -y build-essential git rust

# Clone and build Arch Network
multipass exec dev-env -- git clone https://github.com/Arch-Network/arch-network
multipass exec dev-env -- bash -c "cd arch-network && make all"
```

**VM advantages:**
- **Isolation**: Build environment separate from validator runtime
- **Reproducibility**: Consistent build environment across deployments
- **Resource management**: Dedicated build resources don't impact validator
- **Experimentation**: Safe to modify build environment without affecting production

## Comprehensive Build System

The Arch Network project includes a sophisticated Makefile-based build system that handles dependency tracking, eBPF program compilation, and binary builds:

```bash
# In the dev-env VM - see all available targets
make help

# Build all main binaries (validator, arch-cli, bootnode, local_validator)
make all

# Build individual components
make validator        # Build validator (release)
make arch-cli         # Build arch-cli (release)
make bootnode         # Build bootnode (release)

# Build debug versions for development
make all-debug        # Build all binaries (debug)
make validator-debug  # Build validator (debug)

# Build eBPF programs
make ebpf             # Build all eBPF programs

# Clean build artifacts
make clean            # Clean all build artifacts
make clean-ebpf       # Clean only eBPF programs
```

**Build system features:**
- **Dependency tracking**: Automatically rebuilds when source files change
- **eBPF compilation**: Handles token and associated token account programs
- **Rust toolchain verification**: Ensures correct Rust 1.82.0 is installed
- **Parallel builds**: Leverages all available CPU cores
- **Debug/release modes**: Separate targets for development and production
- **Colored output**: Clear visual feedback on build status
- **Error handling**: Fails fast with clear error messages

**Build dependencies:**
```bash
# The build system automatically handles:
# - eBPF program compilation (token, associated-token-account)
# - Rust dependency management
# - Binary linking with eBPF programs
# - Output directory management
```

**Performance benefits:**
- **Incremental builds**: Only rebuilds changed components
- **Parallel compilation**: Uses all available CPU cores
- **Optimized release builds**: Full optimization for production binaries
- **Fast development cycles**: Debug builds skip heavy optimizations

## Source-Friendly Library Design

The `common.sh` library is designed for both operational use and testing/maintenance:

```bash
# Production usage (automatic sourcing)
./env-init  # Sources common.sh automatically

# Testing/maintenance usage (manual sourcing)
source common.sh
deploy_validator_operator "test-user"    # Test individual functions
clobber_user "test-user"                 # Clean up test resources
```

**Testing workflow:**
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

**Maintenance benefits:**
- **Function-level testing**: Test individual operations without full workflow
- **Debugging**: Inspect state between function calls
- **Development**: Iterate on functions interactively
- **Validation**: Verify idempotency by running functions multiple times
- **Troubleshooting**: Diagnose issues by stepping through operations manually

## Development Workflow Patterns

### 1. Initial Setup
```bash
./env-init    # Create validator operator user and deploy resources
./sync-bins   # Sync latest binaries from dev-env VM
```

### 2. Development Iteration
```bash
# After making changes to resources/* scripts
./env-init    # Redeploy resources (always updates to latest)

# After rebuilding binaries in dev-env VM
./sync-bins   # Sync latest binaries
```

### 3. Validator Operations
```bash
# Start validator (runs in foreground with full logging)
sudo -u testnet-validator /home/testnet-validator/run-validator

# Stop validator (graceful shutdown with fallback to force)
sudo -u testnet-validator /home/testnet-validator/halt-validator

# Check status
ps aux | grep validator

# Monitor logs
tail -f /home/testnet-validator/logs/validator.log
```

## Script Architecture

### Core Infrastructure Scripts

#### `env-init`
**Purpose**: Set up validator operator environment with deploy semantics

**What it does**:
- Removes legacy `arch` user (cleanup from previous iterations)
- Creates/updates `testnet-validator` user
- Ensures proper directory structure exists (`data/`, `logs/`)
- **Always deploys latest scripts** from `resources/` (deploy semantics)
- Configures automatic log rotation (daily, 7-day retention)

**Idempotency**: Safe to run multiple times
**Dependencies**: `resources/run-validator` must exist

#### `sync-bins`
**Purpose**: Synchronize binaries from development VM to bare metal

**What it does**:
- Connects to multipass `dev-env` VM via SCP (robust vs multipass transfer)
- Syncs `arch-cli` and `validator` binaries to `/usr/local/bin/`
- Only overwrites if files have changed (efficient, checksum-based)
- Uses dynamic VM IP detection

**Idempotency**: Safe to run multiple times
**Dependencies**:
- Multipass `dev-env` VM must be running
- SSH access to VM must be configured
- Source binaries must exist in VM at expected paths

### Validator Runtime Scripts

#### `resources/run-validator`
**Purpose**: Validator startup script with comprehensive logging

**What it does**:
- Validates environment is properly set up (fail-fast)
- Logs startup configuration and all operational output
- Configures validator with environment variables (with sensible defaults)
- Starts Arch Network validator in testnet mode
- Tees all output to `$HOME/logs/validator.log`

**Environment Variables**:
- `ARCH_DATA_DIR`: Data directory (default: `$HOME/data/.arch_data`)
- `ARCH_RPC_BIND_IP`: RPC bind IP (default: `127.0.0.1`)
- `ARCH_RPC_BIND_PORT`: RPC port (default: `9002`)
- `ARCH_TITAN_ENDPOINT`: Titan HTTP endpoint (default: testnet endpoint)
- `ARCH_TITAN_SOCKET_ENDPOINT`: Titan TCP endpoint (default: testnet endpoint)
- `ARCH_NETWORK_MODE`: Network mode (default: `testnet`)

#### `resources/halt-validator`
**Purpose**: Graceful validator shutdown with fallback strategies

**What it does**:
- Finds all running validator processes
- Attempts graceful shutdown (SIGTERM, 15-second timeout)
- Falls back to forced shutdown (SIGKILL, 5-second timeout)
- Nuclear option: sudo SIGKILL for stubborn processes
- Logs complete shutdown process with timestamps

**Capabilities**:
- Handles multiple validator processes
- Progress indicators during shutdown waits
- Clear reporting of what happened to each process
- Maximum 25-second shutdown time (vs 30+ seconds for manual kill)

### Monitoring Architecture

#### `validator-dashboard`
**Purpose**: Comprehensive real-time validator monitoring dashboard

**What it does**:
- Creates tmux session with multi-window monitoring layout
- Window 1: Operational guidance and interactive terminal
- Window 2: Split-pane status monitoring and live logs
- Window 3: Split-pane system monitoring (htop/nethogs)
- Uses modular helper scripts for each monitoring function
- Updates validator status continuously with comprehensive health checks

**Environment Variables**:
- `VALIDATOR_USER`: Validator user to monitor (required, no default)

**Session Management**:
- Session name: `{VALIDATOR_USER}-dashboard`
- Safe to run multiple instances for different validators
- Detach/reattach capability for persistent monitoring
- Robust pane management with title-based references

**Helper Scripts**:
- `status-watch`: Continuous status monitoring with `watch`
- `status-check`: Detailed validator status with network health
- `tail-logs`: Live log tailing
- `htop-monitor`: System process monitoring
- `nethogs-monitor`: Network usage monitoring
- `show-help`: Operational guidance for professional operators

## Utility Library Architecture

### `common.sh`
**Purpose**: Shared utility library with validator inspection functions

**What it provides**:
- Infrastructure deployment functions (user management, resource deployment)
- Validator inspection utilities (process status, network health, log analysis)
- Reusable functions for both scripts and interactive sessions
- Consistent error handling and logging patterns

**Key Utility Functions**:
- `get_validator_pid()`, `is_validator_running()`: Process management
- `get_block_height()`, `is_rpc_listening()`: Network connectivity
- `get_titan_connection_status()`, `get_recent_slot()`: Network health
- `get_error_count()`, `get_recent_error_count()`: Error analysis
- `get_data_sizes()`, `get_recent_log_lines()`: System information

**Usage Patterns**:
```bash
# In scripts (automatic sourcing)
./validator-dashboard  # Sources common.sh automatically

# Interactive sessions (manual sourcing)
source common.sh
export VALIDATOR_USER=testnet-validator
echo "Block height: $(get_block_height)"
echo "Validator running: $(is_validator_running "$VALIDATOR_USER" && echo yes || echo no)"
```

**Design Philosophy**:
- **Behavior vs Display**: Utility functions return raw data, display logic handled separately
- **Reusability**: Functions work in scripts, interactive sessions, and other tools
- **Consistency**: All functions follow same error handling and output patterns

## Log Management Architecture

### Automatic Log Rotation
- **Configuration**: Deployed to `/etc/logrotate.d/validator-{username}`
- **Schedule**: Daily rotation
- **Retention**: 7 days of compressed logs
- **Permissions**: Proper user ownership maintained
- **Cleanup**: Removed automatically when validator operator is removed

### Complete Operational Logging
All operational output is captured in `/home/testnet-validator/logs/validator.log`:
- Startup configuration and validation
- All validator process output
- Shutdown process and status
- Timestamps for all major operations
- Script-prefixed output for easy parsing

## Design Principles

### Idempotency
All operations are safe to repeat. Running any script multiple times produces the same result without side effects.

### Fail-Fast
Scripts validate dependencies and fail immediately with clear error messages if prerequisites are not met.

### Deploy Semantics
Resource deployment always ensures the current state matches the desired state, rather than "create once and skip."

### Consistent Output
All scripts use prefixed output (`script-name: message`) for easy identification and log parsing.

### Complete Operational Visibility
Every action is logged with timestamps, configuration details, and clear status reporting.

### Clear Separation of Concerns
- **IaC scripts** (root level): Manage infrastructure and sync binaries
- **Resources** (resources/): Deployable operational scripts
- **Libraries** (common.sh): Shared utilities with consistent interfaces
- **Helpers** (validator-dashboard-helpers/): Modular monitoring components

## Production Features

- **User Isolation**: Dedicated `testnet-validator` user with proper permissions
- **Log Rotation**: Automatic daily rotation with compression and cleanup
- **Robust Process Management**: Multi-stage shutdown with timeout handling
- **Configuration Management**: Environment-driven configuration with defaults
- **Network Integration**: Pre-configured for Arch Network Titan testnet
- **Operational Monitoring**: Complete audit trail of all operations
- **Binary Management**: Efficient sync with change detection
- **Clean State Management**: Idempotent operations ensure consistent deployments

This architecture provides a robust, secure, and maintainable foundation for Arch Network validator operations while maintaining clear separation between development and production environments. 