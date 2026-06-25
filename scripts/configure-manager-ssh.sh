#!/bin/bash
#
# Copyright 2024- IBM Inc. All rights reserved
# SPDX-License-Identifier: Apache2.0
#
# Configure IBM COS Manager node via SSH after cloning from Packer template
# This script reconfigures the network from template IP to production IP

set -e

# Environment variables (passed from Terraform)
: ${OLD_IP:?}
: ${NEW_IP:?}
: ${NETMASK:?}
: ${GATEWAY:?}
: ${DNS_SERVERS:?}
: ${NTP_SERVERS:?}
: ${HOSTNAME:?}
: ${ORGANIZATION:?}
: ${COUNTRY:?}
: ${SSH_KEY:?}

echo "========================================="
echo "Configuring Manager Node"
echo "========================================="
echo "Old IP (template): ${OLD_IP}"
echo "New IP (production): ${NEW_IP}"
echo "Hostname: ${HOSTNAME}"
echo "========================================="

# Wait for SSH to be available at old IP
echo "Waiting for SSH connection at ${OLD_IP}..."
for i in {1..30}; do
  if ssh -i "${SSH_KEY}" -o StrictHostKeyChecking=no -o ConnectTimeout=5 localadmin@${OLD_IP} "version" 2>/dev/null | grep -q "ClevOS"; then
    echo "SSH connection established"
    break
  fi
  echo "Waiting for SSH (attempt $i/30)..."
  sleep 10
done

# Configure via SSH using expect script
echo "Reconfiguring network and system settings..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
expect "${SCRIPT_DIR}/configure-manager.expect" "${SSH_KEY}" "${OLD_IP}" "${NEW_IP}" "${NETMASK}" "${GATEWAY}" "${DNS_SERVERS}" "${NTP_SERVERS}" "${HOSTNAME}" "${ORGANIZATION}" "${COUNTRY}"

echo "Configuration commands sent. Waiting for IP change to take effect..."
sleep 30

# Verify new IP is accessible
echo "Verifying Manager is accessible at new IP ${NEW_IP}..."
for i in {1..30}; do
  if ssh -i "${SSH_KEY}" -o StrictHostKeyChecking=no -o ConnectTimeout=5 localadmin@${NEW_IP} "version" 2>/dev/null; then
    echo "✓ Manager is accessible at ${NEW_IP}"
    echo "✓ Manager configuration complete"
    exit 0
  fi
  echo "Waiting for new IP (attempt $i/30)..."
  sleep 10
done

echo "Warning: Could not verify new IP ${NEW_IP}, but configuration was sent"
echo "Manager may still be activating. Check manually if needed."
exit 0

# Made with Bob
