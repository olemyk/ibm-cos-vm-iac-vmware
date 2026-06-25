#!/bin/bash
#
# Copyright 2024- IBM Inc. All rights reserved
# SPDX-License-Identifier: Apache2.0
#
# setup-ssh-key.sh — Generate the Packer SSH key pair used for VM template automation.
#
# Run this once before building Packer templates:
#   cd packer && ./setup-ssh-key.sh
#
# The private key (packer_rsa) is git-ignored.
# The public key (packer_rsa.pub) is committed and embedded in Packer boot commands.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KEY_FILE="$SCRIPT_DIR/packer_rsa"

echo "=========================================="
echo "IBM COS Packer — SSH Key Setup"
echo "=========================================="
echo ""

if [ -f "$KEY_FILE" ]; then
    echo "✅ Key pair already exists: $KEY_FILE"
    echo "   Delete it first if you want to regenerate:"
    echo "   rm $KEY_FILE $KEY_FILE.pub"
    echo ""
else
    echo "🔑 Generating RSA 4096-bit key pair..."
    ssh-keygen -t rsa -b 4096 -f "$KEY_FILE" -N '' -C 'packer@ibm-cos-automation'
    chmod 600 "$KEY_FILE"
    echo ""
    echo "✅ Key pair created:"
    echo "   Private key: $KEY_FILE  (git-ignored — never commit this)"
    echo "   Public key:  $KEY_FILE.pub"
    echo ""
fi

echo "Public key contents (embedded in Packer boot_command):"
echo "--------------------------------------------------------"
cat "$KEY_FILE.pub"
echo ""
echo "Next step: copy variables.pkrvars.hcl.example → variables.pkrvars.hcl"
echo "         then run: ./build-all-templates.sh"
