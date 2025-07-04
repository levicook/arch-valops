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