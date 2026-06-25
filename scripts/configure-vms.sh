#!/bin/bash
#
# Copyright 2024. All rights reserved
# SPDX-License-Identifier: Apache2.0
#
# This script configures IBM COS VMs after Terraform deployment
# It waits for VMs to boot, then configures network settings via console
#

set -e

# Source configuration from terraform.tfvars
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Read configuration from terraform.tfvars
VCENTER_SERVER=$(grep 'vsphere_server' "$PROJECT_DIR/terraform.tfvars" | cut -d'"' -f2)
VCENTER_USER=$(grep 'vsphere_user' "$PROJECT_DIR/terraform.tfvars" | cut -d'"' -f2)
VCENTER_PASSWORD=$(grep 'vsphere_password' "$PROJECT_DIR/terraform.tfvars" | cut -d'"' -f2)
BASE_IP=$(grep 'base_ip' "$PROJECT_DIR/terraform.tfvars" | cut -d'"' -f2)
GATEWAY=$(grep 'gateway' "$PROJECT_DIR/terraform.tfvars" | cut -d'"' -f2)
DNS=$(grep 'dns_servers' "$PROJECT_DIR/terraform.tfvars" | grep -o '"[^"]*"' | head -1 | tr -d '"')
VM_PREFIX=$(grep 'vm_name_prefix' "$PROJECT_DIR/terraform.tfvars" | cut -d'"' -f2)
NUM_SLICESTORS=$(grep 'slicestor_count' "$PROJECT_DIR/terraform.tfvars" | cut -d'=' -f2 | tr -d ' ')

# Calculate IPs
IP_PREFIX=${BASE_IP%.*}
IP_SUFFIX=${BASE_IP##*.}
MANAGER_IP=$BASE_IP
ACCESSER_IP=${IP_PREFIX}.$((IP_SUFFIX + 1))

echo "=========================================="
echo "IBM COS VM Configuration Script"
echo "=========================================="
echo "vCenter: $VCENTER_SERVER"
echo "Manager IP: $MANAGER_IP"
echo "Accesser IP: $ACCESSER_IP"
echo "Gateway: $GATEWAY"
echo "DNS: $DNS"
echo "=========================================="
echo ""

# Check if expect is installed
if ! command -v expect &> /dev/null; then
    echo "ERROR: 'expect' is not installed. Please install it:"
    echo "  macOS: brew install expect"
    echo "  Linux: sudo apt-get install expect"
    exit 1
fi

# Wait for VMs to boot
echo "Waiting for VMs to boot (4-5 minutes)..."
for i in {1..6}; do
    echo "  Waiting... ($i/6)"
    sleep 45
done

echo ""
echo "VMs should now be booted. Starting configuration..."
echo ""

# Configure Manager
echo "=========================================="
echo "Configuring Manager VM..."
echo "=========================================="
"$SCRIPT_DIR/cos-manager-vmrc.expect" "$VCENTER_SERVER" "$VCENTER_USER" "$VCENTER_PASSWORD" \
    "${VM_PREFIX}-Manager" "$MANAGER_IP" "$GATEWAY" "$DNS"

# Configure Accesser
echo ""
echo "=========================================="
echo "Configuring Accesser VM..."
echo "=========================================="
ACCESSER_IP=${IP_PREFIX}.$((IP_SUFFIX + 1))
"$SCRIPT_DIR/cos-accesser-vmrc.expect" "$VCENTER_SERVER" "$VCENTER_USER" "$VCENTER_PASSWORD" \
    "${VM_PREFIX}-Accesser1" "$ACCESSER_IP" "$GATEWAY" "$DNS" "$MANAGER_IP"

# Configure Slicestors
for I in $(seq 1 $NUM_SLICESTORS); do
    echo ""
    echo "=========================================="
    echo "Configuring Slicestor${I} VM..."
    echo "=========================================="
    SLICESTOR_IP=${IP_PREFIX}.$((IP_SUFFIX + I + 1))
    "$SCRIPT_DIR/cos-slicestor-vmrc.expect" "$VCENTER_SERVER" "$VCENTER_USER" "$VCENTER_PASSWORD" \
        "${VM_PREFIX}-Slicestor${I}" "$SLICESTOR_IP" "$I" "$GATEWAY" "$DNS" "$MANAGER_IP"
done

echo ""
echo "=========================================="
echo "Configuration Complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Access Manager UI: https://$MANAGER_IP"
echo "2. Login with: localadmin / password"
echo "3. Complete cluster setup in the UI"
echo ""

# Made with Bob
