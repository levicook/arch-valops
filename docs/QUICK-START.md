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
sudo apt install -y curl wget git tmux htop nethogs jq build-essential age

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
  HostName 10.142.17.80  # needs to reflect `multipass info dev-env`
  User ubuntu
  ProxyJump your-server
  AddKeysToAgent yes
  ForwardAgent yes
```

## Step 1: Clone and Setup valops

```bash
# Clone the repository
git clone https://github.com/levicook/arch-valops.git ~/valops
cd ~/valops
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

## Step 3: Setup Age Encryption Keys

Set up age encryption keys for secure validator identity deployment:

```bash
# Generate age keypair for identity encryption
./setup-age-keys
```

**What this does:**
- Creates `~/.valops/age/` directory with secure permissions (700)
- Generates age keypair for encrypting/decrypting validator identities
- Displays the public key needed for identity generation

**Expected output:**
```
=== Setting up Age encryption keys ===
Key directory: /home/ubuntu/.valops/age

Generating new age keypair...
Public key created...
Private key created...
✓ Generated new age keypair

=== Host Public Key (for identity encryption) ===
age1r6amd5p6k83ha0fxmeqph68nte3h0fuvr4d75v524cffpxkgaatqzk7q2m

📋 INSTRUCTIONS:
1. Use the public key above as the recipient when encrypting validator identities
```

**Save the public key** - you'll need it for identity generation in Step 5.

## Step 4: Create Development Environment

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

## Step 5: Build Arch Network Binaries

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
ls -la target/release/validator

# Exit the VM
exit
```

## Step 6: Sync Binaries to Bare Metal

```bash
# Back on bare metal, sync binaries from dev-env VM
SYNC_STRATEGY_ARCH=vm sync-arch-bins       # Arch binaries from dev-env VM
SYNC_STRATEGY_BITCOIN=vm sync-bitcoin-bins # Bitcoin binaries from dev-env VM
sync-titan-bins                            # Titan binary from dev-env VM
```

**What this does:**
- Connects to `dev-env` VM via optimized SCP
- Copies binaries to `/usr/local/bin/` (validator, arch-cli, bitcoind, bitcoin-cli, titan)
- Only updates files that have changed (efficient, checksum-based)
- Uses specialized scripts for each binary type

**Expected output:**
```
lib: Syncing Arch Network binaries...
lib: Strategy: vm
lib: VM: dev-env
lib: Syncing validator from dev-env...
lib: ✓ Updated validator
lib: ✓ Arch Network binaries sync complete
```

## Step 7: Generate Validator Identity (Secure Environment)

⚠️ **SECURITY CRITICAL**: This step should ideally be done in a secure, air-gapped environment (separate machine, VM, or offline system).

```bash
# Set the host public key from Step 3
HOST_PUBLIC_KEY="age1r6amd5p6k83ha0fxmeqph68nte3h0fuvr4d75v524cffpxkgaatqzk7q2m"

# Generate validator identity and encrypt secret key
validator --generate-peer-id --data-dir $(mktemp -d) | grep secret_key | cut -d'"' -f4 | age -r "$HOST_PUBLIC_KEY" -o validator-identity.age
```

**What this does:**
- Generates a new validator identity in a temporary directory
- Extracts only the 64-character hex secret key
- Encrypts the secret key with your host's public key
- Creates `validator-identity.age` file for secure transport

**Security Notes:**
- Only the secret key is extracted and encrypted (minimal exposure)
- Temporary directory is automatically cleaned up
- The encrypted file is safe to transfer over insecure channels
- Original identity data never leaves the secure environment

## Step 8: Initialize Validator

Transfer the `validator-identity.age` file to your validator server, then initialize:

```bash
# Initialize validator with encrypted identity (one-time setup)
./validator-init --encrypted-identity-key validator-identity.age --network testnet --user testnet-validator
```

**What this does:**
- Verifies age keys and prerequisites exist
- Creates `testnet-validator` user with proper permissions
- Sets up directory structure (`/home/testnet-validator/{data,logs}`)
- Decrypts and deploys the validator identity securely
- Deploys validator startup/shutdown scripts
- Configures automatic log rotation and firewall rules

**Expected output:**
```
validator-init: Creating testnet-validator user...
validator-init: ✓ Created testnet-validator user
validator-init: Deploying encrypted identity key for testnet-validator...
validator-init: Decrypting encrypted identity key...
validator-init: Verifying secret key format...
validator-init: Installing validator identity...
validator-init: ✓ Encrypted identity key deployed successfully
validator-init:   Network: testnet
validator-init:   Peer ID: 16Uiu2HAmJQbfNZjSCNi8Bw67ND9MvRpMZhh1CCdShQBPYoAveX8m
validator-init:   Location: /home/testnet-validator/data/.arch_data/testnet
validator-init: ✓ Temporary files securely cleaned

✓ Initialized. Start with: ./validator-up --user testnet-validator
```

**📋 Important**: Save the Peer ID shown above - you'll need it to register with the Arch Network.

## Step 9: Start Your Validator

```bash
# Start the validator
./validator-up --user testnet-validator
```

**What this does:**
- Updates validator scripts to latest versions
- Refreshes log rotation and firewall configuration
- Starts the validator process in the background

**Expected output:**
```
validator-up: Ensuring log rotation configuration for testnet-validator...
validator-up: ✓ Ensured logrotate config for testnet-validator
validator-up: Ensuring validator network connectivity...
validator-up: ✓ Ensured RPC port 9002 (localhost only)
validator-up: ✓ Gossip port 29001 already properly configured
validator-up: ✓ Validator started
```

## Step 10: Start Monitoring Dashboard

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

## Step 11: Verify Validator Health

In the monitoring dashboard or a separate terminal:

```bash
# Check validator process
ps aux | grep validator

# Test RPC endpoint
curl -X POST -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"get_block_count","params":[],"id":1}' \
  http://127.0.0.1:9002/

# Monitor logs
tail -f /home/testnet-validator/logs/validator.log

# Check network connectivity
curl -s https://titan-public-tcp.test.arch.network
```

## Validator Lifecycle Management

### Stop Validator
```bash
# Graceful shutdown
./validator-down --user testnet-validator
```

### Restart Validator
```bash
# Stop and start
./validator-down --user testnet-validator
./validator-up --user testnet-validator
```

### Complete Removal (for testing/cleanup)
```bash
# Stop validator and remove all data (DESTRUCTIVE)
./validator-down --clobber --user testnet-validator
```

## Common First-Time Issues

### `setup-age-keys` fails with "age: command not found"
**Problem:** Age encryption tool not installed
**Solution:**
```bash
# Install age
sudo apt install -y age

# Verify installation
age --version
```

### Binary sync fails with "Connection refused"
**Problem:** Can't connect to development VM
**Solution:**
```bash
# Check VM status
multipass list

# Start VM if stopped
multipass start dev-env

# Verify SSH connectivity
multipass exec dev-env -- echo "test"

# Test specific sync scripts
SYNC_STRATEGY_ARCH=vm sync-arch-bins
```

### `validator-init` fails with "Age keys not found"
**Problem:** Age keys not properly set up
**Solution:**
```bash
# Run setup-age-keys first
./setup-age-keys

# Verify keys exist
ls -la ~/.valops/age/
```

### `validator-init` fails with "Failed to decrypt"
**Problem:** Wrong public key used for encryption or corrupted file
**Solution:**
```bash
# Verify public key matches
cat ~/.valops/age/host-identity.pub

# Re-generate identity with correct public key
# (repeat Step 7 with correct HOST_PUBLIC_KEY)
```

### Validator won't start - "Binary not found"
**Problem:** Binaries not properly installed
**Solution:**
```bash
# Check binary installation
which validator
ls -la /usr/local/bin/validator

# Re-sync binaries
SYNC_STRATEGY_ARCH=vm sync-arch-bins
SYNC_STRATEGY_BITCOIN=vm sync-bitcoin-bins
sync-titan-bins

# Verify permissions
sudo chmod +x /usr/local/bin/validator
```

### RPC endpoint not responding
**Problem:** Validator not listening on port 9002
**Solution:**
```bash
# Check if validator is running
./validator-up --user testnet-validator

# Check if port is listening
sudo ss -tlnp | grep 9002

# Check validator logs for errors
tail -20 /home/testnet-validator/logs/validator.log
```

## Development Workflow

### Making Changes
```bash
# After updating resources/* scripts
./validator-down --user testnet-validator
./validator-up --user testnet-validator  # Updates scripts automatically

# After rebuilding binaries in dev-env
# Sync development binaries
SYNC_STRATEGY_ARCH=vm sync-arch-bins
SYNC_STRATEGY_BITCOIN=vm sync-bitcoin-bins
sync-titan-bins

# Or use release binaries for production
ARCH_VERSION=v0.5.3 sync-arch-bins
BITCOIN_VERSION=29.0 sync-bitcoin-bins
./validator-down --user testnet-validator
./validator-up --user testnet-validator  # Restart with new binaries
```

### Monitoring Best Practices
- **Keep dashboard running**: Detach with `Ctrl+b + d`, reattach anytime
- **Watch for errors**: Monitor the logs pane for ERROR/WARN messages
- **Check connectivity**: Ensure Titan network connection stays healthy
- **Monitor resources**: Watch CPU/memory usage in ops window

## Next Steps

Now that your validator is running:

1. **Register Your Validator**: Use the Peer ID from Step 8 to register with Arch Network
2. **Learn Operations**: Read the [Operations Guide](OPERATIONS.md) for day-to-day management
3. **Setup Advanced Monitoring**: Review [Monitoring Guide](MONITORING.md) for comprehensive observability
4. **Understand Security**: Study [Security Guide](SECURITY.md) for production deployment
5. **Explore Architecture**: See [Architecture Guide](ARCHITECTURE.md) for development workflow

## Getting Help

- **Logs**: Always check `/home/testnet-validator/logs/validator.log` first
- **Status**: Use the monitoring dashboard for real-time health checks
- **Documentation**: Each guide has comprehensive troubleshooting sections
- **Interactive Help**: Type `show-help` in any dashboard terminal pane

**Congratulations!** You now have a running Arch Network validator with secure identity management and comprehensive monitoring. 🎉