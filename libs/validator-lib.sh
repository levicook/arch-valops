#!/usr/bin/env bash
#
# validator-lib.sh - Validator-specific utilities for Arch Network operations
#
# Sources core utilities and provides validator-specific functions

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# This library provides idempotent functions for managing validator infrastructure:
# - User management (create/remove users safely)
# - Validator operator deployment (directories, scripts, always-current resources)
# - Project environment detection (git-based project root)
# - Binary synchronization from multipass development VMs
#
# DESIGN PHILOSOPHY:
# - All functions are idempotent (safe for repeated execution)
# - Deploy operations always ensure current state matches desired state
# - Clobber operations safely remove resources when they exist
# - Scripts fail fast with clear error messages when dependencies are missing
#
# OPERATING MODEL:
# - Use multipass 'dev-env' VM to build Arch Network binaries
# - Sync built binaries to bare metal with sync-arch-bins, sync-bitcoin-bins, sync-titan-bins
# - Deploy validator operators with current resources using validator-init
#

# Validator-specific functions (core utilities sourced from lib.sh)

# Generate validator environment file for systemd service
# Parameters: username data_dir rpc_bind_ip rpc_bind_port titan_endpoint titan_socket_endpoint network_mode websocket_enabled websocket_bind_ip websocket_bind_port
generate_validator_environment_file() {
    local username="$1"
    local data_dir="$2"
    local rpc_bind_ip="$3"
    local rpc_bind_port="$4"
    local titan_endpoint="$5"
    local titan_socket_endpoint="$6"
    local network_mode="$7"
    local websocket_enabled="$8"
    local websocket_bind_ip="$9"
    local websocket_bind_port="${10}"

    if [ -z "$username" ] || [ -z "$data_dir" ] || [ -z "$network_mode" ]; then
        log_echo "❌ generate_validator_environment_file: missing required parameters"
        return 1
    fi

    local home_dir="/home/$username"
    local env_file="$home_dir/validator.env"

    log_echo "Generating validator environment file..."

    # Create environment file using native validator env var names
    sudo tee "$env_file" >/dev/null <<EOF
# Arch Network Validator Configuration
# Generated by validator-lib.sh
# Uses native validator environment variable names

# Core Configuration
NETWORK_MODE=$network_mode
DATA_DIR=$data_dir
RPC_BIND_IP=$rpc_bind_ip
RPC_BIND_PORT=$rpc_bind_port
TITAN_ENDPOINT=$titan_endpoint
TITAN_SOCKET_ENDPOINT=$titan_socket_endpoint
EOF

    # Add websocket configuration only if enabled
    if [[ "$websocket_enabled" == "true" ]] && [ -n "$websocket_bind_ip" ] && [ -n "$websocket_bind_port" ]; then
        sudo tee -a "$env_file" >/dev/null <<EOF

# WebSocket Configuration (optional)
WEBSOCKET_BIND_IP=$websocket_bind_ip
WEBSOCKET_BIND_PORT=$websocket_bind_port
EOF
    fi

    # Set secure permissions
    sudo chown "$username:$username" "$env_file"
    sudo chmod 600 "$env_file"

    log_echo "✓ Validator environment file generated: $env_file"
}

# Validator-specific wrapper for generic identity shredding
shred_validator_identities() {
    local username="$1"
    shred_identity_files "$username" "data/.arch_data" "identity-secret"
}

# Idempotent validator operator removal with secure shredding
clobber_validator_operator() {
    local username="$1"

    if id "$username" &>/dev/null; then
        # Remove validator-specific files before generic user removal
        sudo -u "$username" rm -rf \
            "/home/$username/data/.arch_data" \
            "/home/$username/logs/validator.log" \
            "/home/$username/validator.env" 2>/dev/null || true
        log_echo "✓ Removed validator operator files for: $username"

        # Remove logrotate configuration
        if [[ -f "/etc/logrotate.d/validator-$username" ]]; then
            sudo rm "/etc/logrotate.d/validator-$username"
            log_echo "✓ Removed logrotate config for $username"
        fi

        # Use generic user removal (handles identity shredding)
        clobber_user "$username" "data/.arch_data" "identity-secret"
    fi
}

# Idempotent validator operator initialization (one-time setup)
# Only handles identity and infrastructure - configuration is handled separately
init_validator_operator() {
    local username="$1"
    local encrypted_identity_key="$2"
    local network_mode="$3"
    local home_dir="/home/$username"

    # Create user and directories (idempotent)
    create_user "$username"
    sudo -u "$username" mkdir -p "$home_dir"/{data,logs}
    sudo -u "$username" mkdir -p "$home_dir/data/.arch_data"

    # Deploy encrypted identity
    deploy_validator_identity "$username" "$encrypted_identity_key" "$network_mode"

    log_echo "✓ Validator initialization complete"
    log_echo "  Next: Run validator-up to configure and start the service"
}

# Update validator operator configuration (assumes init_validator_operator was run)
# Parameters: username data_dir rpc_bind_ip rpc_bind_port titan_endpoint titan_socket_endpoint network_mode websocket_enabled websocket_bind_ip websocket_bind_port
update_validator_operator() {
    local username="$1"
    local data_dir="$2"
    local rpc_bind_ip="$3"
    local rpc_bind_port="$4"
    local titan_endpoint="$5"
    local titan_socket_endpoint="$6"
    local network_mode="$7"
    local websocket_enabled="$8"
    local websocket_bind_ip="$9"
    local websocket_bind_port="${10}"

    # Verify required parameters
    if [ -z "$username" ] || [ -z "$data_dir" ] || [ -z "$network_mode" ]; then
        log_error "✗ update_validator_operator: missing required parameters"
        return 1
    fi

    # Verify user exists (should have been created by init)
    if ! id "$username" &>/dev/null; then
        log_error "✗ User '$username' not found. Run validator-init first."
        return 1
    fi

    generate_validator_environment_file "$username" "$data_dir" "$rpc_bind_ip" "$rpc_bind_port" "$titan_endpoint" "$titan_socket_endpoint" "$network_mode" "$websocket_enabled" "$websocket_bind_ip" "$websocket_bind_port"

    ensure_logrotate_enabled "$username" "validator"
    ensure_gossip_enabled "$rpc_bind_port" "$websocket_enabled" "$websocket_bind_port"
}

# Deploy encrypted validator identity key
deploy_validator_identity() {
    local username="$1"
    local encrypted_identity_key="$2"
    local network_mode="$3"
    local home_dir="/home/$username"
    local data_dir="$home_dir/data/.arch_data"
    local identity_dir="$data_dir/$network_mode"

    log_echo "Deploying encrypted identity key for $username..."

    # Verify encrypted identity key exists
    if [[ ! -f "$encrypted_identity_key" ]]; then
        log_error "✗ Encrypted identity key not found: $encrypted_identity_key"
        return 1
    fi

    # Verify age keys exist
    if [[ ! -f "$HOME/.valops/age/host-identity.key" ]]; then
        log_error "✗ Age private key not found. Run: setup-age-keys"
        return 1
    fi

    # Check if age is installed
    if ! command -v age >/dev/null 2>&1; then
        log_error "✗ age is not installed. Install with: sudo apt install age"
        return 1
    fi

    # Create temporary directory for decryption
    local temp_dir=$(mktemp -d)
    trap "find '$temp_dir' -type f -exec shred -vfz {} \; 2>/dev/null; rm -rf '$temp_dir'" EXIT

    # Decrypt identity secret key
    log_echo "Decrypting encrypted identity key..."
    if ! age -d -i "$HOME/.valops/age/host-identity.key" "$encrypted_identity_key" >"$temp_dir/secret-key"; then
        log_error "✗ Failed to decrypt encrypted identity key"
        return 1
    fi

    # Verify secret key format (should be 64-character hex)
    log_echo "Verifying secret key format..."
    local secret_key=$(cat "$temp_dir/secret-key")
    if [[ ! "$secret_key" =~ ^[a-f0-9]{64}$ ]]; then
        log_error "✗ Invalid secret key format (expected 64-character hex)"
        return 1
    fi

    # Ensure target directory exists
    sudo -u "$username" mkdir -p "$identity_dir"

    # Create identity files from secret key
    log_echo "Installing validator identity..."

    # Write secret key to identity-secret file (strip any trailing newline)
    tr -d '\n' <"$temp_dir/secret-key" | sudo tee "$identity_dir/identity-secret" >/dev/null

    # Create key_manager directory structure
    sudo mkdir -p "$identity_dir/key_manager/nonces"

    # Set correct ownership and permissions
    sudo chown -R "$username:$username" "$identity_dir"
    sudo chmod 600 "$identity_dir/identity-secret"

    # Verify deployment (run tests as the validator user)
    if sudo -u "$username" test -f "$identity_dir/identity-secret" && sudo -u "$username" test -d "$identity_dir/key_manager"; then
        # Get peer ID for verification
        local peer_id=$(sudo -u "$username" validator --generate-peer-id --data-dir "$data_dir" --network-mode "$network_mode" 2>/dev/null | grep peer_id | cut -d'"' -f4 || echo "unknown")
        log_echo "✓ Encrypted identity key deployed successfully"
        log_echo "  Network: $network_mode"
        log_echo "  Peer ID: $peer_id"
        log_echo "  Location: $identity_dir"
    else
        log_error "✗ Encrypted identity key deployment failed - files not found"
        log_error "  identity-secret exists: $(sudo -u "$username" test -f "$identity_dir/identity-secret" && echo "yes" || echo "no")"
        log_error "  key_manager exists: $(sudo -u "$username" test -d "$identity_dir/key_manager" && echo "yes" || echo "no")"
        return 1
    fi

    # Secure cleanup (shred handled by trap)
    log_echo "✓ Temporary files securely cleaned"
}

# Create encrypted backup of validator identity in ~/.valops/age
backup_validator_identity() {
    local username="$1"
    local network_mode="$2"
    local home_dir="/home/$username"
    local data_dir="$home_dir/data/.arch_data"
    local identity_dir="$data_dir/$network_mode"
    local identity_file="$identity_dir/identity-secret"

    log_echo "Creating encrypted identity backup for $username..."

    # Verify user and identity exist
    if ! id "$username" &>/dev/null; then
        log_error "✗ User '$username' not found"
        return 1
    fi

    if ! sudo -u "$username" test -f "$identity_file"; then
        log_error "✗ Identity file not found: $identity_file"
        log_error "  Is the validator initialized for network '$network_mode'?"
        return 1
    fi

    # Verify age infrastructure exists
    local age_dir="$HOME/.valops/age"
    if [[ ! -f "$age_dir/host-identity.pub" ]]; then
        log_error "✗ Age keys not found. Run: setup-age-keys"
        return 1
    fi

    # Check if age is installed
    if ! command -v age >/dev/null 2>&1; then
        log_error "✗ age is not installed. Install with: sudo apt install age"
        return 1
    fi

    # Get peer ID for naming
    local peer_id=$(sudo -u "$username" validator --generate-peer-id --data-dir "$data_dir" --network-mode "$network_mode" 2>/dev/null | grep peer_id | cut -d'"' -f4 || echo "")
    if [[ -z "$peer_id" || "$peer_id" == "unknown" ]]; then
        log_error "✗ Could not determine peer ID"
        return 1
    fi

    local backup_file="$age_dir/identity-backup-$peer_id.age"

    # Check if backup already exists
    if [[ -f "$backup_file" ]]; then
        log_echo "✓ Identity backup already exists: $backup_file"
        log_echo "  Peer ID: $peer_id"
        log_echo "  Network: $network_mode"
        return 0
    fi

    # Validate identity format before encryption (should be 64-character hex)
    log_echo "Validating identity format..."
    local secret_key=$(sudo cat "$identity_file")
    if [[ ! "$secret_key" =~ ^[a-f0-9]{64}$ ]]; then
        log_error "✗ Invalid identity format (expected 64-character hex)"
        return 1
    fi

    # Encrypt identity directly through pipe
    log_echo "Creating encrypted identity backup..."
    if ! sudo cat "$identity_file" | age -r "$(cat "$age_dir/host-identity.pub")" -o "$backup_file"; then
        log_error "✗ Failed to encrypt identity backup"
        return 1
    fi

    # Set secure permissions (consistent with age directory)
    chmod 600 "$backup_file"

    log_echo "✓ Identity backup created"
    log_echo "  Peer ID: $peer_id"
    log_echo "  Network: $network_mode"
    log_echo "  Backup: $backup_file"
    log_echo ""
    log_echo "💡 BACKUP STRATEGY:"
    log_echo "  Back up entire directory: ~/.valops/age/"
    log_echo "  Contains: host keys + encrypted identity backups"
}

# Create encrypted backups of all validator identities
backup_all_identities() {
    local username="$1"

    log_echo "Creating encrypted backups for all identities of $username..."

    # Verify user exists
    if ! id "$username" &>/dev/null; then
        log_error "✗ User '$username' not found"
        return 1
    fi

    # Verify age infrastructure exists
    local age_dir="$HOME/.valops/age"
    if [[ ! -f "$age_dir/host-identity.pub" ]]; then
        log_error "✗ Age keys not found. Run: setup-age-keys"
        return 1
    fi

    # Find all identity-secret files and backup each one
    local data_dir="/home/$username/data/.arch_data"
    if ! sudo -u "$username" test -d "$data_dir" 2>/dev/null; then
        log_echo "⚠ No .arch_data directory found for $username"
        return 0
    fi

    # Simple approach: iterate through known network directories
    local found_any=false
    for network in testnet mainnet devnet; do
        local identity_file="$data_dir/$network/identity-secret"
        if sudo -u "$username" test -f "$identity_file" 2>/dev/null; then
            log_echo "  Processing $network identity..."
            backup_validator_identity "$username" "$network"
            found_any=true
        fi
    done

    if [[ "$found_any" != "true" ]]; then
        log_echo "⚠ No identity files found for $username"
        log_echo "  Path searched: $data_dir"
        return 0
    fi

    log_echo ""
    log_echo "✓ All identity backups completed"
    log_echo "  Backups stored in: ~/.valops/age/"
    return 0
}

# Project root and script root exported by lib.sh

# Validator inspection utilities
# These functions return raw data without formatting for reuse across scripts

# Process management functions removed - now handled by systemd
# Use: systemctl status arch-validator@$username to check service status
# Use: systemctl is-active arch-validator@$username to check if running

is_rpc_listening() {
    local rpc_port="${RPC_BIND_PORT:-9002}"
    sudo ss -tlnp | grep -q "$rpc_port"
}

get_rpc_response() {
    local method="$1"
    local params="${2:-[]}"
    local rpc_port="${RPC_BIND_PORT:-9002}"
    timeout 3 curl -s -X POST -H "Content-Type: application/json" -d "{\"jsonrpc\":\"2.0\",\"method\":\"$method\",\"params\":$params,\"id\":1}" http://127.0.0.1:$rpc_port/ 2>/dev/null
}

get_block_height() {
    local response=$(get_rpc_response "get_block_count")
    echo "$response" | jq -r ".result // \"unknown\"" 2>/dev/null || echo "unknown"
}

get_titan_connection_status() {
    local username="$1"
    local last_conn=$(sudo su - "$username" -c "grep 'Connected to server at titan-public-tcp' logs/validator.log 2>/dev/null | tail -1" || echo "")
    local last_disconn=$(sudo su - "$username" -c "grep 'Detected disconnection' logs/validator.log 2>/dev/null | tail -1" || echo "")

    if [ -n "$last_conn" ]; then
        local conn_time=$(echo "$last_conn" | cut -d' ' -f1-2)
        if [ -n "$last_disconn" ]; then
            local disconn_time=$(echo "$last_disconn" | cut -d' ' -f1-2)
            if [[ "$disconn_time" > "$conn_time" ]]; then
                echo "disconnected"
            else
                echo "connected"
            fi
        else
            echo "connected"
        fi
    else
        echo "unknown"
    fi
}

get_recent_slot() {
    local username="$1"
    sudo su - "$username" -c "grep 'slot [0-9]*' logs/validator.log 2>/dev/null | tail -1 | grep -o 'slot [0-9]*' | cut -d' ' -f2" || echo "unknown"
}

get_error_count() {
    local username="$1"
    sudo su - "$username" -c "grep -c ERROR logs/validator.log 2>/dev/null | tail -1" || echo "0"
}

get_recent_error_count() {
    local username="$1"
    local hour_ago=$(date -d '1 hour ago' '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date -d '-1 hour' '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "")
    if [ -n "$hour_ago" ]; then
        sudo su - "$username" -c "grep ERROR logs/validator.log 2>/dev/null | grep -c '$hour_ago\\|$(date '+%Y-%m-%d %H')'" || echo "0"
    else
        echo "unknown"
    fi
}

get_last_error() {
    local username="$1"
    sudo su - "$username" -c "grep ERROR logs/validator.log 2>/dev/null | tail -1" || echo ""
}

get_restart_count() {
    local username="$1"
    sudo su - "$username" -c "grep -c 'Starting\\|Initializing\\|startup' logs/validator.log 2>/dev/null" || echo "0"
}

get_last_restart() {
    local username="$1"
    sudo su - "$username" -c "grep 'Starting\\|Initializing\\|startup' logs/validator.log 2>/dev/null | tail -1 | cut -d' ' -f1-2" || echo "unknown"
}

get_data_sizes() {
    local username="$1"
    local ledger_size=$(sudo su - "$username" -c "du -sh data/.arch_data/testnet/ledger 2>/dev/null | cut -f1" || echo "N/A")
    local total_size=$(sudo su - "$username" -c "du -sh data/.arch_data 2>/dev/null | cut -f1" || echo "N/A")
    echo "$ledger_size|$total_size"
}

get_recent_log_lines() {
    local username="$1"
    local count="${2:-2}"
    sudo su - "$username" -c "grep -v 'OpenTelemetry' logs/validator.log 2>/dev/null | tail -$count" || echo ""
}

get_telemetry_error_count() {
    local username="$1"
    sudo su - "$username" -c "grep -c 'OpenTelemetry' logs/validator.log 2>/dev/null" || echo "0"
}

# Enhanced RPC-based monitoring functions
is_node_ready() {
    local response=$(get_rpc_response "is_node_ready")
    echo "$response" | jq -r ".result // false" 2>/dev/null || echo "false"
}

get_best_block_hash() {
    local response=$(get_rpc_response "get_best_block_hash")
    echo "$response" | jq -r ".result // \"unknown\"" 2>/dev/null || echo "unknown"
}

get_block_hash_by_height() {
    local height="$1"
    local response=$(get_rpc_response "get_block_hash" "[$height]")
    echo "$response" | jq -r ".result // \"unknown\"" 2>/dev/null || echo "unknown"
}

get_block_info() {
    local block_hash="$1"
    local response=$(get_rpc_response "get_block" "[\"$block_hash\"]")
    echo "$response" | jq -r ".result // \"unknown\"" 2>/dev/null || echo "unknown"
}

get_processed_transaction() {
    local txid="$1"
    local response=$(get_rpc_response "get_processed_transaction" "[\"$txid\"]")
    echo "$response" | jq -r ".result // \"unknown\"" 2>/dev/null || echo "unknown"
}

# Enhanced block height with better error handling
get_block_height_enhanced() {
    local response=$(get_rpc_response "get_block_count")
    local result=$(echo "$response" | jq -r ".result // null" 2>/dev/null)
    if [ "$result" != "null" ] && [ "$result" != "" ]; then
        echo "$result"
    else
        # Fallback to error details if available
        local error=$(echo "$response" | jq -r ".error.message // \"unknown\"" 2>/dev/null)
        echo "error: $error"
    fi
}

# (ensure_logrotate_enabled now provided by lib.sh)

# Ensure validator gossip and RPC ports are properly configured
# Parameters: rpc_bind_port websocket_enabled websocket_bind_port
ensure_gossip_enabled() {
    local rpc_bind_port="$1"
    local websocket_enabled="$2"
    local websocket_bind_port="$3"

    log_echo "Ensuring validator network connectivity..."

    # Check if ufw is installed and active
    if ! command -v ufw >/dev/null 2>&1; then
        log_echo "⚠ UFW not installed, skipping firewall configuration"
        return 0
    fi

    # Get current ufw status
    local ufw_status=$(sudo ufw status | head -1 | awk '{print $2}')

    if [ "$ufw_status" = "active" ]; then
        log_echo "UFW is active, ensuring validator ports are accessible..."

        # Check for RPC port rule (localhost only) - more specific check
        if ! sudo ufw status numbered | grep -q "127.0.0.1.*$rpc_bind_port"; then
            sudo ufw allow from 127.0.0.1 to any port "$rpc_bind_port" comment "Arch validator RPC (localhost only)" >/dev/null 2>&1 || true
            log_echo "✓ Ensured RPC port $rpc_bind_port (localhost only)"
        else
            log_echo "✓ RPC port $rpc_bind_port already properly configured"
        fi

        # Check for gossip port rule - more specific check
        if ! sudo ufw status numbered | grep -q "29001/tcp"; then
            sudo ufw allow 29001/tcp comment "Arch validator gossip port" >/dev/null 2>&1 || true
            log_echo "✓ Ensured gossip port 29001 (peer communication)"
        else
            log_echo "✓ Gossip port 29001 already properly configured"
        fi

        # Check for websocket port rule (only if enabled)
        if [[ "$websocket_enabled" == "true" ]] && [ -n "$websocket_bind_port" ]; then
            if ! sudo ufw status numbered | grep -q "127.0.0.1.*$websocket_bind_port"; then
                sudo ufw allow from 127.0.0.1 to any port "$websocket_bind_port" comment "Arch validator WebSocket (localhost only)" >/dev/null 2>&1 || true
                log_echo "✓ Ensured WebSocket port $websocket_bind_port (localhost only)"
            else
                log_echo "✓ WebSocket port $websocket_bind_port already properly configured"
            fi
        fi

        log_echo "✓ Validator network connectivity ensured"
    else
        log_echo "✓ UFW not active, no firewall configuration needed"
    fi
}
