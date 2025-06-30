#!/usr/bin/env bash
#
# lib.sh - Core utilities for valops project
#
# Provides basic functions used across all valops scripts:
# - Logging utilities
# - Project structure detection
# - Environment setup
#

# Consistent output functions
log_echo() {
    echo "lib: $@"
}

log_error() {
    echo "lib: $@" >&2
}

project_root() {
    local scripts_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local project_dir="$(cd "$scripts_dir/.." && pwd)"
    echo "$project_dir"
}

# Generic user management utilities
# Used by validator-lib.sh, titan-lib.sh, bitcoin-lib.sh, etc.

# Idempotent user creation
create_user() {
    local username="$1"

    if ! id "$username" &>/dev/null; then
        log_echo "Creating $username user..."
        sudo useradd -r -m -s /bin/bash "$username"
        log_echo "✓ Created $username user"
    fi
}

# Securely shred identity files in specified directory
shred_identity_files() {
    local username="$1"
    local data_dir="$2"
    local filename_pattern="${3:-identity-secret}"

    if id "$username" &>/dev/null; then
        local home_dir="/home/$username"
        if sudo test -d "$home_dir/$data_dir"; then
            sudo find "$home_dir/$data_dir" -name "$filename_pattern" -type f -exec shred -vfz {} \; 2>/dev/null || true
        fi
    fi
}

# Idempotent user removal with secure identity cleanup
clobber_user() {
    local username="$1"
    local data_dir="${2:-data}"
    local filename_pattern="${3:-identity-secret}"

    if id "$username" &>/dev/null; then
        shred_identity_files "$username" "$data_dir" "$filename_pattern"
        log_echo "Removing $username user..."
        sudo userdel -r "$username"
        log_echo "✓ Removed $username user"
    fi
}

# Generic log rotation configuration
ensure_logrotate_enabled() {
    local username="$1"
    local service_name="$2"
    local log_pattern="${3:-*.log}"

    log_echo "Ensuring log rotation configuration for $service_name ($username)..."
    sudo tee "/etc/logrotate.d/$service_name-$username" >/dev/null <<EOF
# Log rotation for $service_name operator: $username
# Managed by valops
/home/$username/logs/$log_pattern {
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
    log_echo "✓ Ensured logrotate config for $service_name-$username"
}

# Systemd IaC Helper Functions

# Ensure systemd service unit is installed and current
ensure_systemd_service_unit_installed() {
    local service_name="$1" # e.g., "arch-bitcoind@"
    local template_file="$PROJECT_ROOT/systemd/${service_name}.service"
    local system_file="/etc/systemd/system/${service_name}.service"

    # Check if service unit needs installation/update
    if [[ ! -f "$system_file" ]] || ! cmp -s "$template_file" "$system_file" 2>/dev/null; then
        log_echo "Installing/updating systemd service unit: $service_name"
        sudo cp "$template_file" "$system_file"
        sudo systemctl daemon-reload
        log_echo "✓ Systemd service unit $service_name installed"
    fi
}

# Check if systemd service is running
is_systemd_service_running() {
    local service_name="$1" # e.g., "arch-bitcoind@testnet-bitcoin"
    systemctl is-active --quiet "$service_name"
}

# Wait for service to be ready with timeout
wait_for_service_ready() {
    local service_name="$1"
    local check_command="$2" # Command to test service readiness
    local timeout="${3:-30}"
    local countdown="$timeout"

    log_echo "Waiting for $service_name to be ready..."
    while [[ $countdown -gt 0 ]]; do
        if eval "$check_command" >/dev/null 2>&1; then
            log_echo "✓ $service_name is ready"
            return 0
        fi
        sleep 1
        countdown=$((countdown - 1))
    done

    log_error "✗ $service_name not ready after ${timeout}s"
    return 1
}

# Generic directory structure creation
ensure_service_directories() {
    local username="$1"
    local directories=("${@:2}") # Array of directories to create

    for dir in "${directories[@]}"; do
        sudo -u "$username" mkdir -p "/home/$username/$dir"
    done
}

# Export standard paths
export PROJECT_ROOT="$(project_root)"
export SCRIPT_ROOT="$PROJECT_ROOT/scripts"
