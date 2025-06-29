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

# Export standard paths
export PROJECT_ROOT="$(project_root)"
export SCRIPT_ROOT="$PROJECT_ROOT/scripts"
