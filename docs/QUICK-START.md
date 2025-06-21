# Quick Start Guide

This guide walks you through setting up your first Arch Network validator using the valops toolkit from a fresh Ubuntu/Debian system to a running validator with monitoring.

## Prerequisites

### System Requirements
- **Ubuntu/Debian bare metal server** with sudo access
- **4GB+ RAM** and **20GB+ disk space** 
- **Network connectivity** to Arch Network endpoints
- **SSH access** configured for remote development

### Required Software
```bash
# Update system packages
sudo apt update && sudo apt upgrade -y

# Install essential packages
sudo apt install -y curl wget git tmux htop nethogs jq build-essential

# Install multipass for development VM
sudo snap install multipass
```

### SSH Configuration (Optional but Recommended)
If developing remotely, configure SSH tunneling:

```bash
# ~/.ssh/config on your laptop
Host your-server
  HostName your-server.example.com
  User ubuntu
  IdentityFile ~/.ssh/your_key
  AddKeysToAgent yes
  ForwardAgent yes

Host dev-env
  HostName 10.142.17.80  # Will be detected automatically
  User ubuntu
  ProxyJump your-server
  AddKeysToAgent yes
  ForwardAgent yes
```

## Step 1: Clone and Setup valops

```bash
# Clone the repository
git clone https://github.com/your-org/valops.git
cd valops

# Make scripts executable
chmod +x check-env env-init sync-bins validator-dashboard
```

## Step 2: Assess Host Security

Before proceeding with validator setup, assess your host security posture:

```bash
# Run comprehensive security assessment
./check-env
```

**What this checks:**
- SSH security configuration and effective settings
- Firewall status and rule configuration
- Intrusion prevention (fail2ban) setup
- System update status and automation
- User security and privilege isolation
- Network service exposure
- System hardening (kernel settings, AppArmor)
- File system security and permissions

**Address any critical issues** identified by the assessment before proceeding. The tool provides specific remediation commands for each issue found.

**Example output:**
```
=== VALOPS HOST ENVIRONMENT SECURITY CHECK ===

🔐 SSH SECURITY
✅ SSH service is active
✅ Root login disabled
✅ Password authentication disabled
ℹ️  SSH running on default port 22

🛡️  FIREWALL SECURITY
✅ UFW firewall is active
✅ SSH access rule configured
✅ Minimal firewall rules (2) - principle of least privilege
```

## Step 3: Create Development Environment

```bash
# Create development VM
multipass launch --name dev-env --memory 4G --disk 20G --cpus 2

# Get VM IP (save this for later)
multipass info dev-env | grep IPv4

# SSH into the VM to set up build environment
multipass exec dev-env -- sudo apt update
multipass exec dev-env -- sudo apt install -y build-essential git curl

# Install Rust (required for Arch Network)
multipass exec dev-env -- bash -c "curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y"
multipass exec dev-env -- bash -c "source ~/.cargo/env && rustup install 1.82.0 && rustup default 1.82.0"
```

## Step 4: Build Arch Network Binaries

```bash
# SSH into development VM
multipass exec dev-env -- bash

# Inside the VM, clone and build Arch Network
git clone https://github.com/Arch-Network/arch-network
cd arch-network

# Source Rust environment
source ~/.cargo/env

# Build all binaries (this may take 10-15 minutes)
make all

# Verify binaries were built
ls -la target/release/{arch-cli,validator}

# Exit the VM
exit
```

## Step 5: Deploy Validator Environment

```bash
# Back on bare metal, deploy validator environment
./env-init
```

**What this does:**
- Creates `testnet-validator` user with proper permissions
- Sets up directory structure (`/home/testnet-validator/{data,logs}`)
- Deploys validator startup/shutdown scripts
- Configures automatic log rotation

**Expected output:**
```
common: Removing arch user...
common: ✓ Removed arch user
common: Creating testnet-validator user...
common: ✓ Created testnet-validator user
common: Setting up directories for testnet-validator...
common: ✓ Created validator directories for testnet-validator
common: Deploying validator scripts for testnet-validator...
common: ✓ Deployed run-validator script for testnet-validator
common: ✓ Deployed halt-validator script for testnet-validator
common: ✓ Deployed logrotate config for testnet-validator
common: ✓ Deployed validator operator for testnet-validator
```

## Step 6: Sync Binaries from Development VM

```bash
# Sync binaries from dev-env VM to bare metal
./sync-bins
```

**What this does:**
- Connects to `dev-env` VM via SCP
- Copies `arch-cli` and `validator` binaries to `/usr/local/bin/`
- Only updates files that have changed (efficient)

**Expected output:**
```
sync-bins: Syncing arch-cli from dev-env (10.142.17.80)...
sync-bins: ✓ Updated arch-cli binary
sync-bins: Syncing validator from dev-env (10.142.17.80)...
sync-bins: ✓ Updated validator binary
sync-bins: ✓ Sync complete!
```

## Step 7: Start Your First Validator

```bash
# Start the validator (runs in foreground with logging)
sudo -u testnet-validator /home/testnet-validator/run-validator
```

**You should see:**
```
run-validator: Starting Arch Network validator...
run-validator: Configuration:
run-validator:   ARCH_DATA_DIR=/home/testnet-validator/data/.arch_data
run-validator:   ARCH_RPC_BIND_IP=127.0.0.1
run-validator:   ARCH_RPC_BIND_PORT=9002
run-validator:   ARCH_TITAN_ENDPOINT=https://titan-public-http.test.arch.network
run-validator:   ARCH_NETWORK_MODE=testnet
run-validator: Validator starting...
[Validator logs will stream here]
```

**Stop the validator:** Press `Ctrl+C` or run in another terminal:
```bash
sudo -u testnet-validator /home/testnet-validator/halt-validator
```

## Step 8: Start Monitoring Dashboard

```bash
# Start comprehensive monitoring (in a new terminal)
VALIDATOR_USER=testnet-validator ./validator-dashboard
```

**Dashboard Layout:**
- **Window 1 (welcome)**: Operational guidance and terminal
- **Window 2 (dashboard)**: Status monitoring + live logs  
- **Window 3 (ops)**: System monitoring (htop + nethogs)

**Navigation:**
- `Ctrl+b + n`: Next window
- `Ctrl+b + p`: Previous window  
- `Ctrl+b + arrows`: Switch panes
- `Ctrl+b + d`: Detach (keeps running)

## Step 9: Verify Validator Health

In the monitoring dashboard or a separate terminal:

```bash
# Check validator process
ps aux | grep arch-cli

# Test RPC endpoint
curl -X POST -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"get_block_count","params":[],"id":1}' \
  http://127.0.0.1:9002/

# Monitor logs
tail -f /home/testnet-validator/logs/validator.log

# Check network connectivity
curl -s https://titan-public-http.test.arch.network | head -5
```

## Common First-Time Issues

### `sync-bins` fails with "Connection refused"
**Problem:** Can't connect to development VM
**Solution:**
```bash
# Check VM status
multipass list

# Start VM if stopped
multipass start dev-env

# Verify SSH connectivity
multipass exec dev-env -- echo "test"
```

### Validator won't start - "Binary not found"
**Problem:** Binaries not properly installed
**Solution:**
```bash
# Check binary installation
which arch-cli validator
ls -la /usr/local/bin/{arch-cli,validator}

# Re-sync binaries
./sync-bins

# Verify permissions
sudo chmod +x /usr/local/bin/{arch-cli,validator}
```

### RPC endpoint not responding
**Problem:** Validator not listening on port 9002
**Solution:**
```bash
# Check if port is listening
sudo ss -tlnp | grep 9002

# Check validator logs for errors
tail -20 /home/testnet-validator/logs/validator.log

# Verify network configuration
sudo ufw status  # Check firewall
```

### Dashboard won't start - "VALIDATOR_USER not set"
**Problem:** Environment variable not configured
**Solution:**
```bash
# Always specify the validator user
VALIDATOR_USER=testnet-validator ./validator-dashboard

# Or export it first
export VALIDATOR_USER=testnet-validator
./validator-dashboard
```

## Development Workflow

### Making Changes
```bash
# After updating resources/* scripts
./env-init  # Redeploys latest scripts

# After rebuilding binaries in dev-env
./sync-bins  # Syncs latest binaries

# Restart validator to use updates
sudo -u testnet-validator /home/testnet-validator/halt-validator
sudo -u testnet-validator /home/testnet-validator/run-validator
```

### Monitoring Best Practices
- **Keep dashboard running**: Detach with `Ctrl+b + d`, reattach anytime
- **Watch for errors**: Monitor the logs pane for ERROR/WARN messages
- **Check connectivity**: Ensure Titan network connection stays healthy
- **Monitor resources**: Watch CPU/memory usage in ops window

## Next Steps

Now that your validator is running:

1. **Learn Operations**: Read the [Operations Guide](OPERATIONS.md) for day-to-day management
2. **Setup Monitoring**: Review [Monitoring Guide](MONITORING.md) for advanced observability
3. **Understand Security**: Study [Security Guide](SECURITY.md) for production deployment
4. **Explore Architecture**: See [Architecture Guide](ARCHITECTURE.md) for development workflow

## Getting Help

- **Logs**: Always check `/home/testnet-validator/logs/validator.log` first
- **Status**: Use the monitoring dashboard for real-time health checks
- **Documentation**: Each guide has comprehensive troubleshooting sections
- **Interactive Help**: Type `show-help` in any dashboard terminal pane

**Congratulations!** You now have a running Arch Network validator with comprehensive monitoring. 🎉 