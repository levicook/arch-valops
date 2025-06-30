# Issue 001: Systemd Migration - Separate Process Management from IaC

**Status**: Open
**Priority**: High
**Date**: June 30, 2025

## Problem

Current architecture mixes infrastructure concerns with process management:
- IaC scripts doing process babysitting (`pgrep`, complex shutdown sequences)
- `run-*`/`halt-*` scripts exist because systemd isn't managing processes
- Bitcoind integration feels bolted-on vs integrated
- Accumulated complexity from manual process supervision

## Solution

**Clean architectural separation**: Infrastructure Management (scripts) vs Process Management (systemd)

### **Target Architecture**
- **IaC Scripts**: Manage infrastructure (users, configs, service units)
- **Systemd**: Manage processes (start, stop, restart, logging)
- **No More**: Custom process lifecycle code in shell scripts

### **IaC Script Pattern**
```bash
# validator-up becomes:
declare_desired_state()
ensure_infrastructure_exists()
systemctl start arch-validator@$USER  # ← Only process interaction
verify_healthy()
```

### **Systemd Service Units**
```ini
# Direct binary execution, no wrapper scripts
[Service]
ExecStart=/usr/local/bin/validator --config /home/%i/validator.conf
Restart=always
```

## Implementation

### **Delete Complexity**
- ❌ `resources/run-validator`, `resources/halt-validator`
- ❌ Complex shutdown sequences in shell scripts
- ❌ Process detection via `pgrep` patterns
- ❌ Manual restart/supervision logic

### **Create Systemd Units**
- ✅ `/etc/systemd/system/arch-validator@.service`
- ✅ `/etc/systemd/system/arch-bitcoind@.service`
- ✅ Direct binary execution (no wrapper scripts)
- ✅ Standard systemd process lifecycle

### **Simplify IaC Scripts**
- ✅ `validator-down` → `systemctl stop` (unless `--clobber`)
- ✅ `bitcoin-up` → ensure infra + `systemctl start`
- ✅ Extract infrastructure helpers to `lib.sh`
- ✅ Consistent declare → ensure → start → verify pattern

### **Unify Integration**
- ✅ Bitcoin and validator use identical IaC patterns
- ✅ No service dependencies (both start independently)
- ✅ Unified helper function usage

## Implementation Strategy

**Pragmatic Approach**: Prove patterns on bitcoin first, then apply to titan and validator

### **Phase 1: Make Bitcoin Entirely Right**
1. Create `arch-bitcoind@.service` with direct binary execution
2. Rewrite `bitcoin-*` scripts to proper IaC patterns (declare → ensure → start → verify)
3. Delete `resources/run-bitcoin`, `resources/halt-bitcoin`
4. Extract bitcoin infrastructure helpers to `lib.sh`
5. Test extensively - bitcoin becomes the reference implementation

### **Phase 2: Implement Titan with Proven Patterns**
1. Create `arch-titan@.service` following bitcoin model
2. Implement `titan-*` scripts using proven IaC patterns
3. Reuse infrastructure helpers from Phase 1
4. Validate pattern consistency

### **Phase 3: Convert Validator to Proven Practices**
1. Migrate `arch-validator@.service` to proven patterns
2. Rewrite `validator-*` scripts following established model
3. Remove validator's custom complexity (halt-validator, etc.)
4. Final cleanup and documentation

## Success Criteria

- [ ] Scripts manage infrastructure, systemd manages processes
- [ ] No custom process lifecycle code in shell scripts
- [ ] `*-up` scripts are idempotent IaC tools
- [ ] Bitcoin and validator management is consistent
- [ ] Dramatically reduced code complexity

## Target Bitcoin Architecture

### **Before (Current)**
```bash
bitcoin-up → update_bitcoin_operator() → generates run-bitcoin → nohup ./run-bitcoin &
             ↘ generates bitcoin.conf
```

### **After (Target)**
```bash
bitcoin-up → ensure_bitcoin_infrastructure() → systemctl start arch-bitcoind@$USER
             ↘ ensures bitcoin.conf current
```

### **Systemd Service Unit**
```ini
# /etc/systemd/system/arch-bitcoind@.service
[Unit]
Description=Bitcoin Core Daemon (%i)
After=network.target

[Service]
Type=simple
User=%i
WorkingDirectory=/home/%i
ExecStart=/usr/local/bin/bitcoind -conf=/home/%i/bitcoin.conf
Restart=always
RestartSec=10
StandardOutput=append:/home/%i/logs/bitcoin.log
StandardError=append:/home/%i/logs/bitcoin.log

# Security
NoNewPrivileges=true
PrivateTmp=true

[Install]
WantedBy=multi-user.target
```

### **New bitcoin-up Pattern**
```bash
#!/bin/bash
declare_bitcoin_state() {
    BITCOIN_USER="${BITCOIN_USER:-testnet-bitcoin}"
    NETWORK_MODE="${BITCOIN_NETWORK_MODE:-testnet}"
}

ensure_bitcoin_infrastructure() {
    ensure_user_exists "$BITCOIN_USER"
    ensure_directories_exist "$BITCOIN_USER"
    ensure_bitcoin_service_unit_installed
    ensure_bitcoin_configuration_current "$BITCOIN_USER" "$NETWORK_MODE"
    ensure_firewall_configured "$NETWORK_MODE"
}

ensure_service_running() {
    systemctl start "arch-bitcoind@$BITCOIN_USER"
    wait_for_bitcoin_rpc_ready "$BITCOIN_USER"
    verify_bitcoin_healthy "$BITCOIN_USER"
}

# Main execution
declare_bitcoin_state
ensure_bitcoin_infrastructure
ensure_service_running
```

## Notes

- **Timeline**: 1-2 days once targets are clear
- **Runtime Config**: Not IaC concern (systemd's job)
- **Service Dependencies**: Not needed (health checks handle readiness)
- **Migration**: Clean break rather than gradual transition