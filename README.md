# Arch Network Validator Operations (valops)

Infrastructure-as-Code toolkit for managing Arch Network validator operations on bare metal.

## Operating Philosophy

This toolkit follows a **hybrid development model**:

1. **Development VM**: Use multipass `dev-env` VM for building binaries (Arch Network and others)
2. **Bare Metal Deployment**: Deploy and run validators on bare metal for performance
3. **IaC Principles**: All operations are idempotent and version-controlled
4. **Deploy Semantics**: Every run ensures system matches desired state

## Project Structure

```
arch-valops/
├── env-init              # Environment setup and user management
├── sync-bins             # Binary synchronization from dev VM
├── common.sh             # Shared utilities library
└── resources/            # Deployable resources
    ├── run-validator     # Validator startup script
    └── halt-validator    # Validator shutdown script
```

## Quick Start

```bash
# 1. Deploy validator environment
./env-init

# 2. Sync latest binaries from dev VM
./sync-bins

# 3. Start validator
sudo -u testnet-validator /home/testnet-validator/run-validator

# 4. Monitor logs (in another terminal)
tail -f /home/testnet-validator/logs/validator.log

# 5. Stop validator
sudo -u testnet-validator /home/testnet-validator/halt-validator
```

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