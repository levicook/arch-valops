#!/usr/bin/env bash
#
# common.sh - Shared utilities for Arch Network validator operations
#
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
# - Sync built binaries to bare metal with sync-bins
# - Deploy validator operators with current resources using validator-init
#

# Consistent output functions
log_echo() {
    echo "common: $@"
}

log_error() {
    echo "common: $@" >&2
}

# Stop validator process
stop_validator() {
    local username="$1"

    if ! is_validator_running "$username"; then
        log_echo "✓ No validator process running for $username"
        return 0
    fi

    local home_dir="/home/$username"
    if sudo -u "$username" test -f "$home_dir/halt-validator"; then
        sudo su - "$username" -c "./halt-validator" || true
        log_echo "✓ Validator stopped"
    else
        log_echo "⚠ halt-validator script not found, attempting direct process termination"
        if sudo su - "$username" -c "pkill -f '^validator --network-mode'" 2>/dev/null; then
            log_echo "✓ Validator process terminated"
        else
            log_echo "✓ No validator process found"
        fi
    fi
}

# Securely shred validator identity files
shred_validator_identities() {
    local username="$1"
    if id "$username" &>/dev/null; then
        local home_dir="/home/$username"
        if sudo test -d "$home_dir/data/.arch_data"; then
            sudo find "$home_dir/data/.arch_data" -name "identity-secret" -type f -exec shred -vfz {} \; 2>/dev/null || true
        fi
    fi
}

# Idempotent user removal with secure shredding
clobber_user() {
    local username="$1"
    if id "$username" &>/dev/null; then
        shred_validator_identities "$username"
        log_echo "Removing $username user..."
        sudo userdel -r "$username"
        log_echo "✓ Removed $username user"
    fi
}

# Idempotent user creation
create_user() {
    local username="$1"

    if ! id "$username" &>/dev/null; then
        log_echo "Creating $username user..."
        sudo useradd -r -m -s /bin/bash "$username"
        log_echo "✓ Created $username user"
    fi
}

# Idempotent validator operator removal with secure shredding
clobber_validator_operator() {
    local username="$1"

    if id "$username" &>/dev/null; then
        shred_validator_identities "$username"

        sudo -u "$username" rm -rf \
            "/home/$username/data/.arch_data" \
            "/home/$username/logs/validator.log" \
            "/home/$username/run-validator" \
            "/home/$username/halt-validator"
        log_echo "✓ Removed validator operator: $username"
    fi

    # Remove logrotate configuration
    if [[ -f "/etc/logrotate.d/validator-$username" ]]; then
        sudo rm "/etc/logrotate.d/validator-$username"
        log_echo "✓ Removed logrotate config for $username"
    fi
}

# Idempotent validator operator initialization (one-time setup)
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

    # Update scripts and configuration
    update_validator_operator "$username"
}

# Update validator operator configuration (assumes init_validator_operator was run)
update_validator_operator() {
    local username="$1"
    local home_dir="/home/$username"

    # Verify user exists (should have been created by init)
    if ! id "$username" &>/dev/null; then
        log_error "✗ User '$username' not found. Run validator-init first."
        return 1
    fi

    # Update validator scripts to latest versions
    sudo cp ./resources/run-validator "$home_dir/run-validator"
    sudo cp ./resources/halt-validator "$home_dir/halt-validator"
    sudo chown "$username:$username" "$home_dir/run-validator" "$home_dir/halt-validator"
    sudo chmod +x "$home_dir/run-validator" "$home_dir/halt-validator"

    ensure_logrotate_enabled "$username"
    ensure_gossip_enabled
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
        log_error "✗ Age private key not found. Run: ./setup-age-keys"
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

git_root() {
    git rev-parse --show-toplevel 2>/dev/null || {
        log_error "✗ Not in a git repository"
        exit 1
    }
}

project_root() {
    local common_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    echo "$common_dir"
}

export PROJECT_ROOT="$(project_root)"

# Validator inspection utilities
# These functions return raw data without formatting for reuse across scripts

get_validator_pid() {
    local username="$1"
    sudo su - "$username" -c "pgrep -f '^validator --network-mode' | head -1" 2>/dev/null || echo ""
}

get_validator_pid_count() {
    local username="$1"
    sudo su - "$username" -c "pgrep -f '^validator --network-mode' | wc -l" 2>/dev/null || echo "0"
}

get_validator_uptime() {
    local username="$1"
    local pid="$2"
    sudo su - "$username" -c "ps -o etime= -p $pid 2>/dev/null | tr -d ' '" || echo "unknown"
}

is_validator_running() {
    local username="$1"
    sudo su - "$username" -c "pgrep -f '^validator --network-mode' >/dev/null" 2>/dev/null
}

is_rpc_listening() {
    sudo ss -tlnp | grep -q 9002
}

get_rpc_response() {
    local method="$1"
    local params="${2:-[]}"
    timeout 3 curl -s -X POST -H "Content-Type: application/json" -d "{\"jsonrpc\":\"2.0\",\"method\":\"$method\",\"params\":$params,\"id\":1}" http://127.0.0.1:9002/ 2>/dev/null
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

# Ensure validator log rotation configuration is current
ensure_logrotate_enabled() {
    local username="$1"

    log_echo "Ensuring log rotation configuration for $username..."
    sudo tee "/etc/logrotate.d/validator-$username" >/dev/null <<EOF
# Log rotation for validator operator: $username
# Managed by valops
/home/$username/logs/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 0644 $username $username
    copytruncate
    su $username $username
}
EOF
    log_echo "✓ Ensured logrotate config for $username"
}

# Ensure validator gossip and RPC ports are properly configured
ensure_gossip_enabled() {
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
        if ! sudo ufw status numbered | grep -q "127.0.0.1.*9002"; then
            sudo ufw allow from 127.0.0.1 to any port 9002 comment "Arch validator RPC (localhost only)" >/dev/null 2>&1 || true
            log_echo "✓ Ensured RPC port 9002 (localhost only)"
        else
            log_echo "✓ RPC port 9002 already properly configured"
        fi

        # Check for gossip port rule - more specific check
        if ! sudo ufw status numbered | grep -q "29001/tcp"; then
            sudo ufw allow 29001/tcp comment "Arch validator gossip port" >/dev/null 2>&1 || true
            log_echo "✓ Ensured gossip port 29001 (peer communication)"
        else
            log_echo "✓ Gossip port 29001 already properly configured"
        fi

        log_echo "✓ Validator network connectivity ensured"
    else
        log_echo "✓ UFW not active, no firewall configuration needed"
    fi
}
