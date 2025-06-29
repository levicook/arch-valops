#!/bin/bash
#
# sync-lib.sh - Common utilities for binary synchronization
#
# Provides shared functions for VM syncing and release downloads
# Used by sync-arch-bins, sync-titan-bins, sync-bitcoin-bins
#

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# Get VM IP address
get_vm_ip() {
    local vm_name="${1:-${VM_NAME:-dev-env}}"
    multipass info "$vm_name" | grep IPv4 | awk '{print $2}'
}

# Sync a binary from VM to /usr/local/bin
sync_binary_from_vm() {
    local vm_path="$1"
    local binary_name="$(basename "$vm_path")"
    local vm_name="${VM_NAME:-dev-env}"
    local target_path="/usr/local/bin/$binary_name"

    log_echo "Syncing $binary_name from $vm_name..."

    local vm_ip=$(get_vm_ip "$vm_name")
    if [[ -z "$vm_ip" ]]; then
        log_error "✗ Could not get IP for VM: $vm_name"
        return 1
    fi

    local temp_dir=$(mktemp -d)
    local temp_file="$temp_dir/$binary_name"

    if scp "$vm_ip:$vm_path" "$temp_file"; then
        if ! cmp -s "$temp_file" "$target_path" 2>/dev/null; then
            sudo cp "$temp_file" "$target_path"
            sudo chmod +x "$target_path"
            log_echo "✓ Updated $binary_name"
        else
            log_echo "✓ $binary_name is up to date"
        fi
    else
        log_error "✗ Failed to transfer $binary_name"
        rm -rf "$temp_dir"
        return 1
    fi

    rm -rf "$temp_dir"
}

# Download binary from GitHub release
download_github_binary() {
    local repo="$1"        # e.g., "Arch-Network/arch-node"
    local binary_name="$2" # e.g., "validator"
    local version="$3"     # e.g., "v0.5.3" (must be specific version tag)
    local platform="$4"    # e.g., "x86_64-unknown-linux-gnu"

    log_echo "Downloading $binary_name from releases ($repo)..."

    local release_url="https://api.github.com/repos/$repo/releases/tags/$version"

    # Get download URL for the binary (exact match: binary-platform)
    local expected_asset_name="${binary_name}-${platform}"
    local download_url=$(curl -s "$release_url" |
        jq -r ".assets[] | select(.name == \"$expected_asset_name\") | .browser_download_url")

    if [[ -z "$download_url" || "$download_url" == "null" ]]; then
        log_error "✗ Binary not found: $expected_asset_name in $repo $version"
        return 1
    fi

    local temp_dir=$(mktemp -d)
    local temp_file="$temp_dir/$binary_name"
    local target_path="/usr/local/bin/$binary_name"

    if curl -L -o "$temp_file" "$download_url"; then
        if ! cmp -s "$temp_file" "$target_path" 2>/dev/null; then
            sudo cp "$temp_file" "$target_path"
            sudo chmod +x "$target_path"
            log_echo "✓ Downloaded $binary_name"
        else
            log_echo "✓ $binary_name is up to date"
        fi
    else
        log_error "✗ Failed to download $binary_name"
        rm -rf "$temp_dir"
        return 1
    fi

    rm -rf "$temp_dir"
}

# Simple platform detection - keep it basic
get_platform() {
    echo "$(uname -m)-unknown-$(uname -s | tr '[:upper:]' '[:lower:]')-gnu"
}
