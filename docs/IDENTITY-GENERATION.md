# Validator Identity Generation

This document describes the secure process for generating and deploying validator identities using age encryption.

## Overview

Validator identities are generated **offline** in a secure environment, encrypted with the target host's public key, and then deployed during `validator-init`. The process extracts only the secret key from the identity and encrypts it for secure transport.

## Environment Flow

```
┌─────────────────────────────────────┐
│ ONLINE HOST / VALIDATOR SERVER      │
│ (Production validator machine)      │
├─────────────────────────────────────┤
│ 1. Run setup-age-keys               │
│ 2. Extract public key               │
└─────────────────────────────────────┘
                  ↓ (share public key)
┌─────────────────────────────────────┐
│ OFFLINE HOST / SECURE ENVIRONMENT   │
│ (Air-gapped machine, secure VM,     │
│  or isolated laptop)                │
├─────────────────────────────────────┤
│ 3. Generate validator identity      │
│ 4. Create encrypted identity key    │
└─────────────────────────────────────┘
                  ↓ (transfer encrypted identity key)
┌─────────────────────────────────────┐
│ ONLINE HOST / VALIDATOR SERVER      │
│ (Production validator machine)      │
├─────────────────────────────────────┤
│ 5. Deploy via validator-init        │
│ 6. Discover peer ID (shown at init) │
│ 7. Register with Arch Network       │
│ 8. Start validator                  │
└─────────────────────────────────────┘
```

## Key Points

- **Simple Format**: Only the 64-character hex secret key is encrypted and transported as an encrypted identity key
- **Secure Generation**: Identity created in controlled environment using proper temp directories
- **One-Way Deployment**: Host can only decrypt the encrypted identity key, never extract plaintext after deployment
- **Immediate Discovery**: Peer ID is shown during initialization for registration with Arch Network

## Step-by-Step Instructions

### Prerequisites

**On Offline Host/Secure Environment:**
- `age` encryption tool installed
- `validator` binary available

**On Online Host/Validator Server:**
- Run `./setup-age-keys` to generate age keypair
- Extract public key: `cat ~/.valops/age/host-identity.pub`

### Step 1: Generate and Encrypt Identity (Offline Host/Secure Environment)

The EXACT command to create the encrypted identity key:

```bash
# Set the validator server's public key (from cat ~/.valops/age/host-identity.pub on validator server)
HOST_PUBLIC_KEY="age1your-host-public-key-here"

# Generate identity and encrypt secret key in one command
validator --generate-peer-id --data-dir $(mktemp -d) | grep secret_key | cut -d'"' -f4 | age -r "$HOST_PUBLIC_KEY" -o validator-identity.age
```

This creates `validator-identity.age` containing the encrypted identity key.

### Step 2: Transfer and Deploy (Online Host/Validator Server)

Securely transfer the encrypted identity key `validator-identity.age` to the validator server using your preferred secure method (scp, rsync, encrypted USB, etc.).

Then deploy the encrypted identity key:

```bash
# On the validator server
./validator-init --encrypted-identity-key validator-identity.age --network testnet --user testnet-validator
```

**Expected output includes the Peer ID:**
```
validator-init: ✓ Encrypted identity key deployed successfully
validator-init:   Network: testnet
validator-init:   Peer ID: 16Uiu2HAmJQbfNZjSCNi8Bw67ND9MvRpMZhh1CCdShQBPYoAveX8m
validator-init:   Location: /home/testnet-validator/data/.arch_data/testnet
```

### Step 3: Register Peer ID (Online Host/Validator Server)

The peer ID is displayed during initialization (Step 2 above). Register this peer ID with Arch Network via Telegram before starting the validator.

**Alternative method** to retrieve the peer ID after initialization:

```bash
# Get the deployed peer ID (if needed later)
sudo -u testnet-validator validator --generate-peer-id --data-dir /home/testnet-validator/data/.arch_data --network-mode testnet | grep peer_id | cut -d'"' -f4
```

## Security Considerations

- **Proper temp directories**: Always use `mktemp -d` for temporary files
- **Secure cleanup**: Use `shred -vfz` to securely delete temporary files
- **Minimal exposure**: Only the secret key is transported as an encrypted identity key, not full identity data
- **One-time use**: Temporary directory is completely removed after use
- **No persistent files**: Nothing is left in the secure environment

## Troubleshooting

**Error: "age: no identity found"**
- Run `./setup-age-keys` on the host to generate age keypair

**Error: "Invalid secret key format"**
- Verify the encrypted file contains exactly 64 hex characters
- Check that the identity generation completed successfully

**Error: "Failed to decrypt encrypted identity key"**
- Verify the correct host public key was used during encryption
- Ensure the encrypted identity key wasn't corrupted during transfer

**Error: "All options are required"**
- `validator-init` requires all three parameters: `--encrypted-identity-key`, `--network`, and `--user`
- Example: `./validator-init --encrypted-identity-key validator-identity.age --network testnet --user testnet-validator`