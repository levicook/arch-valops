# Arch Network Validator Operations (valops)

Infrastructure-as-Code toolkit for managing Arch Network validator operations on bare metal.

## Operating Philosophy

This toolkit follows a **hybrid development model**:

1. **Development VM**: Use multipass `dev-env` VM for building binaries (Arch Network and others)
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

### Security Model: Key Material Isolation

A critical security feature of this architecture is **complete isolation of sensitive key materials** from development and build environments:

```
Developer Laptop    Bare Metal Server    Multipass VM
     │                     │                 │
 🔐 SSH Keys          🚫 No Keys        🚫 No Keys
 🔐 GitHub Token      🚫 No Tokens      🚫 No Tokens
 🔐 GPG Keys          🚫 No GPG         🚫 No GPG
     │                     │                 │
     └─── Agent Forward ───┴─── Tunnel ─────┘
```

**Key isolation benefits:**
- **Zero key exposure**: Private keys never leave the developer's laptop
- **Compromise resistance**: If VM or server is compromised, no keys are exposed
- **Development safety**: Build environments can't access or exfiltrate credentials
- **Audit clarity**: All authenticated operations trace back to developer's laptop
- **Rotation simplicity**: Key rotation only affects developer's local environment

**What stays on the laptop:**
- SSH private keys (GitHub, server access)
- GPG signing keys
- GitHub personal access tokens
- Any other authentication credentials

**What's forwarded securely:**
- SSH authentication capability (via agent)
- Git operations (via forwarded SSH)
- GitHub API access (via forwarded credentials)

**What never gets copied:**
- Private key material
- Token strings
- Credential files
- Authentication secrets

This model ensures that even if the development VM or bare metal server is fully compromised, attackers cannot access your GitHub account, sign commits on your behalf, or impersonate your development identity.

### Security Benefits for Validator Operations

This architecture provides enhanced security for cryptocurrency validator infrastructure:

**Development Security:**
- **Code integrity**: All commits are signed with developer's GPG key (never exposed)
- **Supply chain protection**: Build environments can't inject malicious code into repositories
- **Identity verification**: All GitHub operations maintain proper attribution
- **Credential scope**: Access limited to what's needed for specific operations

**Operational Security:**
- **Build isolation**: Compromised build environment can't affect validator keys or funds
- **Limited blast radius**: Server compromise doesn't expose development credentials
- **Audit trail**: All authenticated operations traceable to specific developer
- **Key rotation**: Developer key rotation doesn't require server access

**Validator-Specific Protections:**
- **Separation of concerns**: Validator private keys completely separate from development keys
- **Environment isolation**: Build tools never interact with validator key material
- **Development safety**: Developers can work on validator code without access to funds
- **Deployment control**: Only binaries (not credentials) flow from development to production

**Critical: Validator Signing Key Isolation**

The most important security aspect is that **validator signing keys** (the actual cryptocurrency keys that control funds and staking operations) are **completely isolated** from this entire development and deployment infrastructure:

```
🔐 Validator Signing Keys (Hardware/Secure Storage)
    │
    ❌ NEVER exposed to:
    │
    ├── Developer laptops
    ├── Development VMs
    ├── Bare metal servers
    ├── Build processes
    ├── Deployment scripts
    └── Any part of valops toolkit
```

**Key isolation layers:**
- **Development keys**: SSH, GPG, GitHub tokens (isolated to laptop via agent forwarding)
- **Infrastructure keys**: Server access, VM management (minimal scope)
- **Validator signing keys**: Cryptocurrency operations (completely separate, hardware-secured)

**Financial security guarantee:**
- Even **total compromise** of the entire valops infrastructure cannot access validator funds
- **Hardware security modules** or **air-gapped systems** hold actual validator keys
- **Development workflow** operates with zero knowledge of financial key material
- **Binary deployment** is completely separate from key management operations

**Threat Model Coverage:**
- ✅ **Compromised development VM**: No credential exposure
- ✅ **Compromised bare metal server**: No GitHub/development access
- ✅ **Supply chain attacks**: Limited to build environment only
- ✅ **Insider threats**: Developers can't access validator private keys
- ✅ **Key exposure**: Development keys isolated from validator operations
- ✅ **Complete infrastructure compromise**: Validator signing keys remain secure
- ✅ **Fund theft attempts**: No access path to cryptocurrency keys
- ✅ **Malicious binary injection**: Cannot access existing validator keys
- ✅ **Social engineering**: Development access cannot compromise funds

This layered security approach ensures that validator operations remain secure even if development or deployment infrastructure is compromised.

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

### Comprehensive Build System

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

### Source-Friendly Library Design

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

**Building binaries in dev-env:**
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

**Testing binary sync:**
```bash
# On bare metal - test sync process
./sync-bins

# Verify installation
which arch-cli validator
arch-cli --version
```

**Validating environment setup:**
```bash
# Test complete deployment
./env-init

# Verify all components
sudo -u testnet-validator ls -la /home/testnet-validator/
cat /etc/logrotate.d/validator-testnet-validator
sudo logrotate -d /etc/logrotate.d/validator-testnet-validator
```

### Debugging Production Issues

**Log analysis:**
```bash
# Monitor real-time operations
tail -f /home/testnet-validator/logs/validator.log

# Search specific events
grep "run-validator:" /home/testnet-validator/logs/validator.log | tail -10
grep "halt-validator:" /home/testnet-validator/logs/validator.log | tail -5

# Check startup configurations
grep "Configuration:" /home/testnet-validator/logs/validator.log | tail -1
```

**Process management:**
```bash
# Check validator status
ps aux | grep validator
sudo -u testnet-validator pgrep -f "arch-cli validator-start"

# Test shutdown behavior
sudo -u testnet-validator /home/testnet-validator/halt-validator
```

**Environment validation:**
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

## Project Structure

```
valops/
├── env-init                          # Environment setup and user management
├── sync-bins                         # Binary synchronization from dev VM
├── common.sh                         # Shared utilities library
├── validator-dashboard               # Comprehensive monitoring dashboard
├── validator-dashboard-helpers/      # Dashboard helper scripts
│   ├── htop-monitor                  # System process monitoring
│   ├── nethogs-monitor               # Network usage monitoring
│   ├── show-help                     # Operational guidance
│   ├── status-check                  # Validator status information
│   ├── status-watch                  # Continuous status monitoring
│   └── tail-logs                     # Live log tailing
├── resources/                        # Deployable resources
│   ├── run-validator                 # Validator startup script
│   └── halt-validator                # Validator shutdown script
└── docs/                             # Detailed documentation
    ├── MONITORING.md                 # Monitoring and observability guide
    ├── OPERATIONS.md                 # Day-to-day operational procedures
    └── API.md                        # Common.sh utility function reference
```

## Quick Start

```bash
# 1. Deploy validator environment
./env-init

# 2. Sync latest binaries from dev VM
./sync-bins

# 3. Start validator
sudo -u testnet-validator /home/testnet-validator/run-validator

# 4. Monitor with comprehensive dashboard
VALIDATOR_USER=testnet-validator ./validator-dashboard

# 5. Stop validator
sudo -u testnet-validator /home/testnet-validator/halt-validator
```

## Documentation

This README provides an architectural overview and development context. For detailed operational guidance, see:

- **[📊 Monitoring Guide](docs/MONITORING.md)** - Comprehensive monitoring, alerting, and observability
- **[⚙️ Operations Guide](docs/OPERATIONS.md)** - Day-to-day validator management and maintenance
- **[🔧 API Reference](docs/API.md)** - Complete reference for `common.sh` utility functions

**Quick Links:**
- New to validator operations? Start with [Operations Guide](docs/OPERATIONS.md)
- Setting up monitoring? See [Monitoring Guide](docs/MONITORING.md)
- Need to use utility functions? Check [API Reference](docs/API.md)
- Troubleshooting issues? Both guides have comprehensive troubleshooting sections

## Validator Monitoring

### Comprehensive Dashboard

The `validator-dashboard` script provides real-time observability through a tmux-based dashboard:

```bash
# Start monitoring dashboard
VALIDATOR_USER=testnet-validator ./validator-dashboard

# Monitor different validator users
VALIDATOR_USER=mainnet-validator ./validator-dashboard
```

**Dashboard Layout:**
- **Window 1 (welcome)**: Operational guidance and bash terminal
- **Window 2 (dashboard)**: Split-pane real-time monitoring
  - Top: Continuous validator status monitoring (updates every 10 seconds)
  - Bottom: Live validator logs with real-time updates
- **Window 3 (ops)**: System monitoring
  - Top: `htop` - System resources (CPU, memory, processes)
  - Bottom: `nethogs` - Network usage by process

**Navigation:**
- `Ctrl+b` then `n`: Switch between windows
- `Ctrl+b` then arrow keys: Switch between panes
- `Ctrl+b` then `d`: Detach (keeps running in background)
- `tmux attach -t {validator-user}-dashboard`: Reattach to existing session

**Status Dashboard Features:**
- ✅ Process status with PID tracking
- 🌐 Network connection verification (RPC port 9002)
- 💾 Data storage metrics (ledger size, total data)
- 📊 Recent log activity (last 3 lines)
- 🔗 Quick RPC connectivity test
- 🕐 Real-time updates every 10 seconds

### Manual Monitoring Commands

```bash
# Check validator process status
sudo su - testnet-validator -c "pgrep -f arch-cli && echo 'Running' || echo 'Stopped'"

# Monitor real-time logs
sudo su - testnet-validator -c "tail -f logs/validator.log"

# Check RPC endpoint health
curl -X POST -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"ping","params":[],"id":1}' \
  http://127.0.0.1:9002/

# Monitor data growth
sudo su - testnet-validator -c "du -sh data/.arch_data/testnet/ledger"

# Check network connections
sudo ss -tlnp | grep 9002

# Search for errors in logs
sudo su - testnet-validator -c "grep -i error logs/validator.log | tail -10"

# Monitor Titan connectivity
sudo su - testnet-validator -c "grep -i titan logs/validator.log | tail -10"
```

### Monitoring Best Practices

**Session Management:**
- Use descriptive session names: `{validator-user}-dashboard`
- Keep monitoring sessions running in background with `Ctrl+b d`
- Reattach when needed without interrupting monitoring

**Resource Monitoring:**
- Watch for memory growth in validator process
- Monitor network usage during sync operations
- Track disk space growth in data directory

**Log Analysis:**
- Monitor for ERROR or WARN messages
- Track Titan connection status
- Watch for block height progression
- Monitor RPC endpoint responsiveness

**Alert Indicators:**
- ❌ Validator process stopped unexpectedly
- ❌ RPC port not listening
- ❌ No recent log activity (> 5 minutes)
- ❌ Titan connection failures
- ❌ Rapid disk space growth

### Troubleshooting with Monitoring

**Validator Not Starting:**
1. Check status dashboard for process state
2. Review recent logs in real-time pane
3. Switch to ops terminal and run diagnostics
4. Use log analysis window for error searching

**Performance Issues:**
1. Monitor CPU/memory usage in htop pane
2. Check network usage in nethogs pane
3. Track data directory growth rates
4. Monitor RPC response times

**Network Connectivity:**
1. Watch Titan connection messages in logs
2. Monitor network usage patterns
3. Test RPC endpoint responsiveness
4. Check for connection timeouts or errors

## Development Workflow

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

## Script Contracts

### `validator-dashboard`
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

**Dependencies**: tmux, htop, nethogs, jq, curl, sudo access to validator user
**Output**: Creates interactive tmux session with real-time monitoring

**Helper Scripts**:
- `status-watch`: Continuous status monitoring with `watch`
- `status-check`: Detailed validator status with network health
- `tail-logs`: Live log tailing
- `htop-monitor`: System process monitoring
- `nethogs-monitor`: Network usage monitoring
- `show-help`: Operational guidance for professional operators

### `env-init`
**Purpose**: Set up validator operator environment with deploy semantics

**What it does**:
- Removes legacy `arch` user (cleanup from previous iterations)
- Creates/updates `testnet-validator` user
- Ensures proper directory structure exists (`data/`, `logs/`)
- **Always deploys latest scripts** from `resources/` (deploy semantics)
- Configures automatic log rotation (daily, 7-day retention)

**Idempotency**: Safe to run multiple times
**Dependencies**: `resources/run-validator` must exist
**Output**: Prefixed with `common:` for easy identification

### `sync-bins`
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
**Output**: Prefixed with `sync-bins:` for easy identification

### `resources/run-validator`
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

**Output**: Prefixed with `run-validator:` in logs

### `resources/halt-validator`
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

**Output**: Prefixed with `halt-validator:` in logs

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

**See**: `docs/API.md` for complete function reference

## Log Management

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

### Log Monitoring
```bash
# Real-time monitoring
tail -f /home/testnet-validator/logs/validator.log

# Search for specific events
grep "run-validator:" /home/testnet-validator/logs/validator.log
grep "halt-validator:" /home/testnet-validator/logs/validator.log

# Check startup configurations
grep "Configuration:" /home/testnet-validator/logs/validator.log
```

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

## Prerequisites

- Ubuntu/Debian bare metal system with sudo access
- Multipass installed and configured
- `dev-env` VM created and accessible via SSH
- Git repository for version control
- Network connectivity to Arch Network testnet endpoints

## Production Features

- **User Isolation**: Dedicated `testnet-validator` user with proper permissions
- **Log Rotation**: Automatic daily rotation with compression and cleanup
- **Robust Process Management**: Multi-stage shutdown with timeout handling
- **Configuration Management**: Environment-driven configuration with defaults
- **Network Integration**: Pre-configured for Arch Network Titan testnet
- **Operational Monitoring**: Complete audit trail of all operations
- **Binary Management**: Efficient sync with change detection
- **Clean State Management**: Idempotent operations ensure consistent deployments

## Troubleshooting

### `env-init` fails with "run-validator script not found"
Ensure `resources/run-validator` exists in the project directory.

### `sync-bins` fails with connection errors
- Verify `dev-env` VM is running: `multipass list`
- Check SSH connectivity: `multipass exec dev-env -- echo "test"`
- Verify VM IP: `multipass info dev-env | grep IPv4`

### Validator fails to start
- Check logs: `tail -f /home/testnet-validator/logs/validator.log`
- Verify binaries: `which arch-cli && which validator`
- Check environment: `sudo -u testnet-validator ls -la /home/testnet-validator/`
- Verify network connectivity: `curl -s https://titan-public-http.test.arch.network`

### Validator won't stop
- Check process status: `ps aux | grep validator`
- Try manual halt: `sudo -u testnet-validator /home/testnet-validator/halt-validator`
- Check logs for shutdown details: `grep "halt-validator:" /home/testnet-validator/logs/validator.log`

### Log rotation not working
- Check configuration: `cat /etc/logrotate.d/validator-testnet-validator`
- Test manually: `sudo logrotate -d /etc/logrotate.d/validator-testnet-validator`
- Verify permissions: `ls -la /home/testnet-validator/logs/`

## Contributing

This is Infrastructure-as-Code. All changes should:
1. Maintain idempotency
2. Include clear error messages with proper stderr routing
3. Follow the deploy semantics pattern
4. Use consistent output formatting with script prefixes
5. Provide complete operational logging
6. Be tested on clean systems
7. Update this documentation with new features
