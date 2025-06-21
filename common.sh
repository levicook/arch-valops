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
# - Deploy validator operators with current resources using env-init
#

# Consistent output functions
log_echo() {
    echo "common: $@"
}

log_error() {
    echo "common: $@" >&2
}

# Idempotent user removal
clobber_user() {
    local username="$1"
    if id "$username" &>/dev/null; then
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

# Idempotent validator operator removal
clobber_validator_operator() {
    local username="$1"

    if id "$username" &>/dev/null; then
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

# Idempotent validator operator deployment
deploy_validator_operator() {
    local username="$1"
    local home_dir="/home/$username"

    # Ensure user exists
    create_user "$username"
    
    # Ensure directories exist
    if ! sudo test -d "$home_dir/data/.arch_data" || ! sudo test -d "$home_dir/logs"; then
        log_echo "Setting up directories for $username..."
        sudo -u "$username" mkdir -p "$home_dir"/{data,logs}
        sudo -u "$username" mkdir -p "$home_dir/data/.arch_data"
        log_echo "✓ Created validator directories for $username"
    else
        log_echo "✓ Validator directories already exist for $username"
    fi

    # Always deploy the latest run-validator script
    log_echo "Deploying validator scripts for $username..."
    if [[ -f "./resources/run-validator" ]]; then
        sudo cp ./resources/run-validator "$home_dir/run-validator"
        sudo chown "$username:$username" "$home_dir/run-validator"
        sudo chmod +x "$home_dir/run-validator"
        log_echo "✓ Deployed run-validator script for $username"
    else
        log_error "✗ run-validator script not found in ./resources/"
        log_error "Cannot deploy validator operator without run-validator script"
        return 1
    fi

    if [[ -f "./resources/halt-validator" ]]; then
        sudo cp ./resources/halt-validator "$home_dir/halt-validator"
        sudo chown "$username:$username" "$home_dir/halt-validator"
        sudo chmod +x "$home_dir/halt-validator"
        log_echo "✓ Deployed halt-validator script for $username"
    else
        log_echo "⚠ halt-validator script not found in ./resources/ (optional)"
    fi

    # Deploy logrotate configuration
    log_echo "Deploying log rotation configuration for $username..."
    sudo tee "/etc/logrotate.d/validator-$username" > /dev/null << EOF
# Log rotation for validator operator: $username
# Deployed by valops env-init
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
    log_echo "✓ Deployed logrotate config for $username"

    log_echo "✓ Deployed validator operator for $username"
    log_echo "Runner: /home/$username/run-validator"
    log_echo "Logs:   /home/$username/logs/"
    log_echo "Rotation: /etc/logrotate.d/validator-$username"
}

git_root() {
    git rev-parse --show-toplevel 2>/dev/null || {
        log_error "✗ Not in a git repository"
        exit 1
    }
}

export PROJECT_ROOT="$(git_root)"
