# Security Guide

🔒 **For**: Security teams and production decision-makers
🎯 **Focus**: Security model, threat analysis, production recommendations

## Security Architecture Overview

**Defense in Depth**: Multiple isolation layers protect validator funds and operations.

### Key Principle: Separation of Concerns
```
Development Keys    →  SSH, GPG, GitHub access (laptop-only)
Infrastructure Keys →  Server access, age encryption
Validator Keys      →  Signing keys, never touched by tooling
```

**Security Guarantee**: Complete compromise of development/operations infrastructure cannot access validator signing keys or funds.

## Threat Model

### What This System Protects Against

✅ **Development Infrastructure Compromise**
- Attacker gains access to development VM, laptops, CI/CD
- **Impact**: Cannot access validator signing keys (encrypted separately)
- **Mitigation**: Age encryption, offline identity generation

✅ **Operations Server Compromise**
- Attacker gains root access to validator server
- **Impact**: Cannot decrypt identity keys (require separate age keys)
- **Mitigation**: Encrypted identity files, key separation

✅ **Credential Theft**
- SSH keys, GitHub tokens, development credentials stolen
- **Impact**: Cannot access validator operations (separate key hierarchy)
- **Mitigation**: SSH agent forwarding, no stored production credentials

✅ **Supply Chain Attacks**
- Compromised dependencies, malicious binaries
- **Impact**: Limited by binary verification and VM isolation
- **Mitigation**: Official release downloads, VM build isolation

### What This System Does NOT Protect Against

❌ **Physical Access to Validator Server**
- Mitigation: Use secure hosting, encrypted disks, physical security

❌ **Compromise of Age Private Keys**
- Mitigation: Secure age key storage, consider hardware security modules

❌ **Social Engineering for Direct Key Access**
- Mitigation: Operational security training, access controls

❌ **Vulnerabilities in Validator Binary Itself**
- Mitigation: Keep binaries updated, monitor security advisories

## Production Security Recommendations

### Essential: Identity Generation Security

**Critical**: Generate validator identities on secure, offline machines.

```bash
# On secure/offline machine:
# 1. Download validator binary securely
# 2. Generate identity
validator --generate-peer-id --data-dir $(mktemp -d) | grep secret_key | cut -d'"' -f4 | age -r "$HOST_PUBLIC_KEY" -o validator-identity.age
# 3. Transfer encrypted file via secure channel
# 4. Securely wipe temporary data
```

**Requirements**:
- Air-gapped or offline machine for generation
- Verified validator binary (checksum/signature verification)
- Secure transfer of encrypted identity file
- Proper disposal of temporary identity data

### Essential: Age Key Management

**Age private keys are the master secret** - protect them like root CA keys.

**Recommended Storage**:
- Hardware Security Modules (HSM) for production
- Encrypted USB drives in secure physical locations
- Key escrow with multiple trustees for disaster recovery

**Access Control**:
- Separate age keys per validator environment (testnet/mainnet)
- Audit logs for age key usage
- Regular key rotation procedures

### Essential: Network Security

**Validator Network Exposure**:
```bash
# Ports that should be exposed:
# 29001 - Gossip network (required for P2P)
# 9002  - RPC (localhost only, SSH tunnel for access)

# Firewall configuration (automatic via validator-up):
sudo ufw allow 29001    # Gossip
sudo ufw allow ssh      # Management access
# RPC port NOT exposed externally
```

**Access Patterns**:
- SSH access with key-based authentication only
- RPC access via SSH tunneling (never direct)
- Monitoring systems should use read-only endpoints

### Recommended: Binary Verification

**For Production**: Use official releases with verification:
```bash
# Use specific versions, not 'latest'
ARCH_VERSION=v0.5.3 sync-arch-bins
BITCOIN_VERSION=29.0 sync-bitcoin-bins

# TODO: Add signature verification
# (Feature request: GPG signature verification for releases)
```

**For Development**: VM strategy provides additional isolation:
```bash
# Development builds are isolated to VM environment
SYNC_STRATEGY_ARCH=vm sync-arch-bins
```

### Recommended: Monitoring Security

**Log Security**:
- Validator logs contain operational data, not secrets
- Safe to aggregate to central logging systems
- Monitor for unusual patterns, errors, restart frequency

**Metrics Exposure**:
- RPC endpoint metrics safe for monitoring systems
- Process and system metrics safe for collection
- No sensitive data exposed in monitoring interfaces

## Security Verification Checklist

### Before Production Deployment

- [ ] **Identity Generation**: Created on secure/offline machine
- [ ] **Age Keys**: Stored securely, access controlled
- [ ] **Network**: Firewall configured, RPC not exposed
- [ ] **SSH**: Key-based authentication, no password auth
- [ ] **Updates**: System updates automated, binary updates planned
- [ ] **Monitoring**: Centralized logging, alerting configured
- [ ] **Backups**: Identity backups verified, recovery tested
- [ ] **Documentation**: Operations team trained on procedures

### Ongoing Security Maintenance

**Weekly**:
- Review SSH access logs
- Verify firewall configuration unchanged
- Check for security updates

**Monthly**:
- Test backup/recovery procedures
- Review age key access patterns
- Audit validator configuration changes

**Quarterly**:
- Rotate SSH keys
- Review and test disaster recovery procedures
- Security assessment of hosting environment

## Incident Response

### Suspected Compromise

**Immediate Actions**:
1. **Isolate**: Disconnect validator from network
2. **Assess**: Determine scope of potential compromise
3. **Preserve**: Take forensic images, preserve logs
4. **Communicate**: Notify relevant stakeholders

**Recovery Options**:
```bash
# Complete validator rebuild (if server compromised):
# 1. Build new server with new SSH keys
# 2. Restore validator identity from backup
VALIDATOR_ENCRYPTED_IDENTITY_KEY=~/.valops/age/identity-backup-{peer-id}.age validator-init
# 3. Resume operations with monitoring
```

### Age Key Compromise

**If age private keys are compromised**:
1. **Generate new validator identity** (new keypair required)
2. **Re-register** with new peer ID
3. **Decommission** old validator completely
4. **Investigate** how compromise occurred

## Compliance Considerations

### Data Protection
- No personally identifiable information stored
- Validator identity is cryptographic keypair only
- Logs contain operational data, network communications

### Audit Requirements
- All operations logged with timestamps
- Identity backup/restore operations auditable
- Change management via version control

### Regulatory Alignment
- Air-gapped identity generation supports compliance requirements
- Key separation aligns with financial services security standards
- Monitoring capabilities support operational risk management

## Advanced Security Options

### Hardware Security Modules (HSM)
Consider HSM integration for:
- Age private key protection
- Validator identity key generation
- Hardware-backed attestation

### Network Segmentation
For large deployments:
- Dedicated VLAN for validator operations
- Jump boxes for administrative access
- Separate monitoring network

### Multi-Signature Operations
Future enhancement options:
- Multi-party age key management
- Threshold signatures for validator operations
- Governance controls for configuration changes

---

**Security questions?** → Contact security team | **Production deployment?** → [OPERATIONS.md](OPERATIONS.md) | **Identity generation?** → [IDENTITY-GENERATION.md](IDENTITY-GENERATION.md)