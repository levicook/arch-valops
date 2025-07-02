#!/usr/bin/env bash
#
# env-lib.sh - Environment configuration helper functions
#
# Pure utility functions for environment configuration.
# Used by .envrc files and configuration scripts.
#
# These functions are side-effect free and return values via echo.
#

# Password management utility for validator environments
ensure_dot_env_password_exists() {
    local var_name="$1"
    local target_dir="$2"
    local password_file="${target_dir}/.env.passwords"

    # Create file if it doesn't exist
    if [[ ! -f "$password_file" ]]; then
        touch "$password_file"
        chmod 600 "$password_file"
    fi

    # Check if variable already exists in file
    if ! grep -q "^${var_name}=" "$password_file" 2>/dev/null; then
        # Generate strong password and append
        local password=$(openssl rand -hex 32)
        echo "${var_name}=${password}" >>"$password_file"
        echo "✓ Generated ${var_name} in ${password_file}"
    fi
}

# Mode selection utility for environment configuration
# Parameters: mode local_value remote_value
# Returns: selected value based on mode
select_by_mode() {
    local mode="$1"
    local local_value="$2"
    local remote_value="$3"

    case "${mode:-remote}" in
    local) echo "$local_value" ;;
    *) echo "$remote_value" ;;
    esac
}

# Default data directory for a given user
# Parameters: username
# Returns: default data directory path
default_data_dir() {
    local username="$1"
    echo "/home/$username/data/.arch_data"
}

# Default endpoints for a given network and mode
# Parameters: network mode
# Returns: appropriate endpoint URL
default_titan_endpoint() {
    local network="$1"
    local mode="${2:-remote}"

    case "$mode" in
    local)
        echo "http://127.0.0.1:3030"
        ;;
    *)
        case "$network" in
        devnet) echo "https://titan-public-http.dev.arch.network" ;;
        mainnet) echo "https://titan-public-http.arch.network" ;;
        regtest) echo "https://titan-public-http.dev.arch.network" ;; # devnet uses regtest bitcoin
        testnet) echo "https://titan-public-http.test.arch.network" ;;
        *) echo "https://titan-public-http.test.arch.network" ;; # fallback to testnet
        esac
        ;;
    esac
}

# Default socket endpoints for a given network and mode
# Parameters: network mode
# Returns: appropriate socket endpoint
default_titan_socket_endpoint() {
    local network="$1"
    local mode="${2:-remote}"

    case "$mode" in
    local)
        echo "127.0.0.1:3030"
        ;;
    *)
        case "$network" in
        devnet) echo "titan-public-tcp.dev.arch.network:3030" ;;
        mainnet) echo "titan-public-tcp.arch.network:3030" ;;
        regtest) echo "titan-public-tcp.dev.arch.network:3030" ;; # devnet uses regtest bitcoin
        testnet) echo "titan-public-tcp.test.arch.network:3030" ;;
        *) echo "titan-public-tcp.test.arch.network:3030" ;; # fallback to testnet
        esac
        ;;
    esac
}

# Display environment status for validator environments
# Parameters: env_name validator_user bitcoin_user network_mode bitcoin_network_mode bitcoin_prune_size titan_mode titan_endpoint websocket_enabled websocket_bind_ip websocket_bind_port
display_environment_status() {
    local env_name="$1"
    local validator_user="$2"
    local bitcoin_user="$3"
    local network_mode="$4"
    local bitcoin_network_mode="$5"
    local bitcoin_prune_size="$6"
    local titan_mode="$7"
    local titan_endpoint="$8"
    local websocket_enabled="$9"
    local websocket_bind_ip="${10}"
    local websocket_bind_port="${11}"

    echo "🔧 $env_name environment loaded"
    echo "  VALIDATOR_USER=$validator_user (ARCH_NETWORK_MODE=$network_mode)"
    echo "  BITCOIN_USER=$bitcoin_user (BITCOIN_NETWORK_MODE=$bitcoin_network_mode, prune=${bitcoin_prune_size}MB)"

    if [[ "$titan_mode" == "local" ]]; then
        echo "  TITAN_USER=${TITAN_USER:-$validator_user} (TITAN_NETWORK_MODE=${TITAN_NETWORK_MODE:-$network_mode}, mode=$titan_mode)"
    else
        echo "  ARCH_TITAN_ENDPOINT=$titan_endpoint (mode=${titan_mode:-remote})"
    fi

    echo ""
    echo "📋 Available commands:"
    echo "  # Validator operations:"
    echo "  validator-init      # Initialize $env_name validator (needs VALIDATOR_ENCRYPTED_IDENTITY_KEY)"
    echo "  validator-up        # Start $env_name validator"
    echo "  validator-down      # Stop $env_name validator"
    echo "  validator-dashboard # Monitor $env_name validator"
    echo ""
    echo "  # Bitcoin operations:"
    echo "  bitcoin-up          # Start $env_name bitcoin node"
    echo "  bitcoin-down        # Stop $env_name bitcoin node"
    echo ""

    if [[ "$titan_mode" == "local" ]]; then
        echo "  # Titan operations (local mode):"
        echo "  titan-up            # Start $env_name titan indexer"
        echo "  titan-down          # Stop $env_name titan indexer"
        echo ""
    fi

    echo ""
    echo "🔌 WebSocket Access:"
    if [[ "$websocket_enabled" == "true" ]]; then
        echo "  WebSocket ENABLED on $websocket_bind_ip:$websocket_bind_port"
        echo "  SSH forward: ssh -L $websocket_bind_port:127.0.0.1:$websocket_bind_port ubuntu@server"
        echo "  Connect to: ws://localhost:$websocket_bind_port"
    else
        echo "  WebSocket DISABLED (set ARCH_WEBSOCKET_ENABLED=true to enable)"
    fi

    echo ""
    echo "💡 Customize by creating .env file in this directory"
}
