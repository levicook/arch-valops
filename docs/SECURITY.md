# Security Guide

This guide explains the security model, key isolation strategies, and threat analysis for the valops toolkit.

## Security Model: Key Material Isolation

A critical security feature of this architecture is **complete isolation of sensitive key materials** from development and build environments:

```
Developer Laptop    Bare Metal Server    Multipass VM
     │                     │                 │
 🔐 SSH Keys          🚫 No Keys        🚫 No Keys
 🔐 GitHub Token      🚫 No Tokens      🚫 No Tokens
 🔐 GPG Keys          🚫 No GPG         🚫 No GPG
     │                     │                 │
     └─── Agent Forward ───┴─── Tunnel ─────┘
```

### Key Isolation Benefits

- **Zero key exposure**: Private keys never leave the developer's laptop
- **Compromise resistance**: If VM or server is compromised, no keys are exposed
- **Development safety**: Build environments can't access or exfiltrate credentials
- **Audit clarity**: All authenticated operations trace back to developer's laptop
- **Rotation simplicity**: Key rotation only affects developer's local environment

### What Stays on the Laptop

- SSH private keys (GitHub, server access)
- GPG signing keys
- GitHub personal access tokens
- Any other authentication credentials

### What's Forwarded Securely

- SSH authentication capability (via agent)
- Git operations (via forwarded SSH)
- GitHub API access (via forwarded credentials)

### What Never Gets Copied

- Private key material
- Token strings
- Credential files
- Authentication secrets

This model ensures that even if the development VM or bare metal server is fully compromised, attackers cannot access your GitHub account, sign commits on your behalf, or impersonate your development identity.

## Security Benefits for Validator Operations

This architecture provides enhanced security for cryptocurrency validator infrastructure:

### Development Security

- **Code integrity**: All commits are signed with developer's GPG key (never exposed)
- **Supply chain protection**: Build environments can't inject malicious code into repositories
- **Identity verification**: All GitHub operations maintain proper attribution
- **Credential scope**: Access limited to what's needed for specific operations

### Operational Security

- **Build isolation**: Compromised build environment can't affect validator keys or funds
- **Limited blast radius**: Server compromise doesn't expose development credentials
- **Audit trail**: All authenticated operations traceable to specific developer
- **Key rotation**: Developer key rotation doesn't require server access

### Validator-Specific Protections

- **Separation of concerns**: Validator private keys completely separate from development keys
- **Environment isolation**: Build tools never interact with validator key material
- **Development safety**: Developers can work on validator code without access to funds
- **Deployment control**: Only binaries (not credentials) flow from development to production

## Critical: Validator Signing Key Isolation

The most important security aspect is that **validator signing keys** (the actual cryptocurrency keys that control funds and staking operations) are **completely isolated** from this entire development and deployment infrastructure:

```
🔐 Validator Signing Keys (Hardware/Secure Storage)
    │
    ❌ NEVER exposed to:
    │
    ├── Developer laptops
    ├── Development VMs
    ├── Bare metal servers
    ├── Build processes
    ├── Deployment scripts
    └── Any part of valops toolkit
```

### Key Isolation Layers

1. **Development keys**: SSH, GPG, GitHub tokens (isolated to laptop via agent forwarding)
2. **Infrastructure keys**: Server access, VM management (minimal scope)
3. **Validator signing keys**: Cryptocurrency operations (completely separate, hardware-secured)

### Financial Security Guarantee

- Even **total compromise** of the entire valops infrastructure cannot access validator funds
- **Hardware security modules** or **air-gapped systems** hold actual validator keys
- **Development workflow** operates with zero knowledge of financial key material
- **Binary deployment** is completely separate from key management operations

## Threat Model Coverage

### Covered Threats

- ✅ **Compromised development VM**: No credential exposure
- ✅ **Compromised bare metal server**: No GitHub/development access
- ✅ **Supply chain attacks**: Limited to build environment only
- ✅ **Insider threats**: Developers can't access validator private keys
- ✅ **Key exposure**: Development keys isolated from validator operations
- ✅ **Complete infrastructure compromise**: Validator signing keys remain secure
- ✅ **Fund theft attempts**: No access path to cryptocurrency keys
- ✅ **Malicious binary injection**: Cannot access existing validator keys
- ✅ **Social engineering**: Development access cannot compromise funds

### Risk Mitigation Strategies

**For Compromised Development VM:**
- No keys stored locally
- Build environment isolation
- Limited network access
- Automated security updates

**For Compromised Bare Metal Server:**
- No development credentials stored
- Minimal attack surface
- Process isolation via dedicated users
- Network segmentation

**For Supply Chain Attacks:**
- Reproducible builds
- Binary verification
- Source code integrity checks
- Dependency scanning

**For Insider Threats:**
- Principle of least privilege
- Audit logging
- Multi-person approval for critical changes
- Role-based access control

## Layered Security Architecture

This layered security approach ensures that validator operations remain secure even if development or deployment infrastructure is compromised.

### Layer 1: Network Security

```bash
# Firewall configuration
sudo ufw enable
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw allow 9002/tcp  # RPC port (if needed externally)

# Network monitoring
sudo ss -tlnp | grep -E "(22|9002)"
sudo netstat -tulnp | grep LISTEN
```

### Layer 2: System Security

```bash
# User isolation
id testnet-validator
sudo -l -U testnet-validator

# Process isolation
ps aux | grep testnet-validator
sudo -u testnet-validator ps -u testnet-validator

# File permissions
ls -la /home/testnet-validator/
sudo find /home/testnet-validator/ -type f -perm /o+w
```

### Layer 3: Application Security

```bash
# Binary integrity
which arch-cli validator
md5sum /usr/local/bin/{arch-cli,validator}

# Configuration security
sudo -u testnet-validator cat /home/testnet-validator/run-validator
grep -E "(ARCH_|export)" /home/testnet-validator/run-validator
```

### Layer 4: Operational Security

```bash
# Log monitoring
grep -i error /home/testnet-validator/logs/validator.log | tail -10
grep -i "auth\|fail\|denied" /var/log/auth.log | tail -10

# Access monitoring
last -n 20
sudo journalctl -u ssh | tail -20
```

## Security Monitoring

### Key Security Indicators

**Process Monitoring:**
```bash
# Monitor validator process integrity
ps aux | grep testnet-validator

# Check for unexpected processes
sudo -u testnet-validator ps -u testnet-validator

# Monitor process resource usage
top -u testnet-validator
```

**Network Monitoring:**
```bash
# Monitor network connections
sudo ss -tulnp | grep testnet-validator

# Check for unexpected connections
sudo netstat -tulnp | grep -E "(9002|3030)"

# Monitor network traffic
sudo nethogs -u testnet-validator
```

**File System Monitoring:**
```bash
# Monitor file integrity
sudo find /home/testnet-validator/ -type f -newer /tmp/last_check

# Check for suspicious files
sudo find /home/testnet-validator/ -name ".*" -type f
sudo find /home/testnet-validator/ -perm /o+w -type f
```

### Security Verification

**Important:** Validator signing keys are managed separately from this infrastructure. The valops toolkit never handles cryptocurrency keys.

```bash
# Verify no private keys in validator directories
sudo -u testnet-validator find /home/testnet-validator/ -name "*.key" -o -name "*.pem"

# Check for any credential files
sudo -u testnet-validator find /home/testnet-validator/ -name "*secret*" -o -name "*private*"

# Verify SSH agent forwarding (from development machine)
ssh-add -l  # Should show keys on laptop
ssh bare-metal-server "ssh-add -l"  # Should show same keys via forwarding
ssh dev-env "ssh-add -l"  # Should show same keys via tunnel
```

## Production Security Checklist

### Infrastructure Security

- [ ] SSH key-based authentication only (no passwords)
- [ ] SSH agent forwarding configured properly
- [ ] Firewall configured with minimal open ports
- [ ] System packages updated regularly
- [ ] Dedicated validator user with minimal privileges
- [ ] Log rotation configured and working
- [ ] Monitoring dashboard secured

### Development Security

- [ ] Development VM isolated from production
- [ ] No credentials stored in development environment
- [ ] Source code integrity verification
- [ ] Binary builds reproducible and verified
- [ ] Git commits signed with GPG
- [ ] GitHub access via SSH agent forwarding only

### Validator Security

- [ ] Validator signing keys stored separately (hardware/air-gapped)
- [ ] Validator process runs as dedicated user
- [ ] Network connections limited to required endpoints
- [ ] Logs monitored for security events
- [ ] Regular security updates applied
- [ ] Backup/recovery procedures tested

### Operational Security

- [ ] Access logs monitored regularly
- [ ] Failed authentication attempts tracked
- [ ] Unusual network activity investigated
- [ ] Process integrity verified regularly
- [ ] File system integrity monitored
- [ ] Incident response procedures documented

## Security Best Practices

### For Developers

1. **Use hardware security keys** for GitHub authentication
2. **Keep development keys secure** on local machines only
3. **Regularly rotate SSH keys** and update server access
4. **Use GPG signing** for all commits
5. **Verify binary integrity** before deployment
6. **Monitor for unauthorized access** to development systems

### For Operators

1. **Isolate validator operations** from development workflows
2. **Monitor validator processes** continuously
3. **Implement proper backup procedures** for configuration only
4. **Use dedicated networks** for validator communication
5. **Regularly audit system access** and permissions
6. **Keep security documentation** up to date

### For Infrastructure

1. **Implement defense in depth** across all layers
2. **Use principle of least privilege** for all access
3. **Monitor and log all security-relevant events**
4. **Regularly test incident response procedures**
5. **Keep all systems updated** with security patches
6. **Implement proper network segmentation**

## Emergency Response

### Suspected Compromise

**Immediate Actions:**
1. **Isolate affected systems** from network
2. **Preserve logs** and evidence
3. **Verify validator key security** (should be unaffected)
4. **Assess scope** of potential compromise
5. **Implement containment** measures

**Recovery Actions:**
1. **Rebuild compromised systems** from clean state
2. **Rotate all infrastructure keys** and credentials
3. **Verify validator signing keys** remain secure
4. **Update security procedures** based on lessons learned
5. **Monitor for ongoing threats**

### Security Contact

For security issues or questions:
- Create a private issue in the repository
- Follow responsible disclosure practices
- Include detailed information about potential vulnerabilities
- Allow reasonable time for response and remediation

**Remember: The most critical security principle is that validator signing keys (the actual cryptocurrency keys) are never exposed to any part of this development or deployment infrastructure.** 