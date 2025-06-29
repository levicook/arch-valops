# valops Migration Guide

🚀 **Major improvements have been made to valops!** This guide helps you understand what's changed and how to use the new, cleaner interface.

## 📋 What Changed

### 1. 🎯 **Environment Variables First**
**Old:** Flag-based interface
```bash
./validator-up --user testnet-validator --network testnet
```

**New:** Environment variable-driven (cleaner, better direnv integration)
```bash
VALIDATOR_USER=testnet-validator validator-up
```

> **Backward Compatibility:** All old flag commands still work! The new interface is additive.

### 2. 📁 **Clean Directory Structure**
**Old:** Scripts scattered in project root
```bash
./validator-up    # Run from project root only
```

**New:** Scripts organized in `scripts/` directory, work from anywhere
```bash
validator-up      # Works from any directory!
```

### 3. 🏗️ **Pre-configured Environments**
**New:** Ready-to-use validator environments
```bash
cd validators/testnet && direnv allow
# 🔧 Testnet validator environment loaded
#   VALIDATOR_USER=testnet-validator
#   ARCH_NETWORK_MODE=testnet

validator-up      # Uses testnet config automatically
```

### 4. 🔄 **Directory-Agnostic Operation**
**Old:** Must run from project root
```bash
cd ~/valops && ./validator-up
```

**New:** Works from anywhere
```bash
cd ~/valops/docs && validator-up      # ✅ Works!
cd ~/valops/validators/testnet && validator-up  # ✅ Works!
cd ~ && validator-up                  # ✅ Works if scripts/ in PATH!
```

## 🚀 Quick Migration

### If you're using the old patterns:

**1. Set up the new environment structure:**
```bash
cd ~/valops
eval "$(direnv hook bash)"    # Enable direnv in current shell
```

**2. Choose your approach:**

**Option A: Use pre-configured environment (recommended)**
```bash
cd validators/testnet
direnv allow
validator-up      # Uses testnet-validator automatically
```

**Option B: Use environment variables**
```bash
VALIDATOR_USER=testnet-validator validator-up
```

**Option C: Keep using flags (works unchanged)**
```bash
validator-up --user testnet-validator  # Still works!
```

## 📚 Updated Command Reference

### Old → New Quick Reference

| Old Command | New Command (Environment) | New Command (Pre-configured) |
|-------------|-------------------------|------------------------------|
| `./check-env` | `check-env` | `check-env` |
| `./setup-age-keys` | `setup-age-keys` | `setup-age-keys` |
| `./validator-init --user foo --network testnet --encrypted-identity-key bar.age` | `VALIDATOR_USER=foo ARCH_NETWORK_MODE=testnet VALIDATOR_ENCRYPTED_IDENTITY_KEY=bar.age validator-init` | `cd validators/testnet && VALIDATOR_ENCRYPTED_IDENTITY_KEY=bar.age validator-init` |
| `./validator-up --user foo` | `VALIDATOR_USER=foo validator-up` | `cd validators/testnet && validator-up` |
| `./validator-down --user foo` | `VALIDATOR_USER=foo validator-down` | `cd validators/testnet && validator-down` |
| `VALIDATOR_USER=foo ./validator-dashboard` | `VALIDATOR_USER=foo validator-dashboard` | `cd validators/testnet && validator-dashboard` |
| `./backup-identities --user foo` | `VALIDATOR_USER=foo backup-identities` | `cd validators/testnet && backup-identities` |

## 🛠️ Available Environments

The project now includes three pre-configured environments:

```bash
# Testnet validator
cd validators/testnet && direnv allow
# Sets: VALIDATOR_USER=testnet-validator, ARCH_NETWORK_MODE=testnet, etc.

# Mainnet validator
cd validators/mainnet && direnv allow
# Sets: VALIDATOR_USER=mainnet-validator, ARCH_NETWORK_MODE=mainnet, etc.

# Development network
cd validators/devnet && direnv allow
# Sets: VALIDATOR_USER=devnet-validator, ARCH_NETWORK_MODE=devnet, etc.
```

**Customize any environment:**
```bash
cd validators/testnet
echo "VALIDATOR_USER=my-custom-validator" > .env
# Now validator-up uses my-custom-validator instead of testnet-validator
```

## 🔧 Environment Setup

### First-time direnv setup:
```bash
# 1. Install direnv (if not already installed)
sudo apt install direnv

# 2. Add to your shell (if not already done)
echo 'eval "$(direnv hook bash)"' >> ~/.bashrc
source ~/.bashrc

# 3. Navigate to project and allow
cd ~/valops
direnv allow

# 4. Use pre-configured environments
cd validators/testnet
direnv allow
```

## 📖 Documentation Status

- ✅ **README.md** - **UPDATED** with all new patterns
- ⚠️ **docs/\*.md** - Still show old patterns, refer to README.md for current usage

> **Note:** The detailed documentation in `docs/` still shows the old flag-based patterns. For the most current information, refer to the updated **README.md** which demonstrates all the new environment variable patterns and pre-configured environments.

## 🎯 Benefits of the New Approach

1. **🔄 Better direnv Integration** - Environment variables work perfectly with direnv
2. **📁 Cleaner Project Structure** - Scripts organized, works from any directory
3. **⚡ Faster Setup** - Pre-configured environments reduce setup time
4. **🔒 Flexible Configuration** - Override any setting with `.env` files
5. **🔧 Backward Compatible** - All old commands still work
6. **🌍 Universal Access** - Commands work from anywhere in the project

## 💡 Best Practices

**For daily operations:**
```bash
# Use pre-configured environments
cd validators/testnet
validator-up
validator-dashboard
validator-down
```

**For automation/scripts:**
```bash
# Use explicit environment variables
VALIDATOR_USER=testnet-validator validator-up
```

**For quick one-offs:**
```bash
# Use flags (backward compatibility)
validator-up --user testnet-validator
```

---

**🚀 Ready to use the new patterns?** Check out the updated [README.md](README.md) for complete examples and documentation.