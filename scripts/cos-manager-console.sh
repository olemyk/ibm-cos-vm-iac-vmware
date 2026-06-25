#!/bin/bash
#
# Copyright 2024. All rights reserved
# SPDX-License-Identifier: Apache2.0
#
# Configure IBM COS Manager VM network via govc console automation
#
# Usage: cos-manager-console.sh <vm_name> <ip> <gateway> <dns>

set -e

VM_NAME="$1"
IP="$2"
GATEWAY="$3"
DNS="$4"

if [ -z "$VM_NAME" ] || [ -z "$IP" ] || [ -z "$GATEWAY" ] || [ -z "$DNS" ]; then
    echo "Usage: $0 <vm_name> <ip> <gateway> <dns>"
    exit 1
fi

echo "Configuring Manager VM: $VM_NAME"
echo "IP: $IP, Gateway: $GATEWAY, DNS: $DNS"

# Check if govc is installed
if ! command -v govc &> /dev/null; then
    echo "ERROR: 'govc' is not installed."
    echo "Install with: brew tap govmomi/tap/govc && brew install govmomi/tap/govc"
    echo "Or download from: https://github.com/vmware/govmomi/releases"
    exit 1
fi

# Check if GOVC environment variables are set
if [ -z "$GOVC_URL" ]; then
    echo "ERROR: GOVC environment variables not set."
    echo "Please set: GOVC_URL, GOVC_USERNAME, GOVC_PASSWORD, GOVC_INSECURE"
    echo "Example:"
    echo "  export GOVC_URL=vcenter.example.com"
    echo "  export GOVC_USERNAME=administrator@vsphere.local"
    echo "  export GOVC_PASSWORD=yourpassword"
    echo "  export GOVC_INSECURE=true"
    exit 1
fi

# Wait for VM to be ready
echo "Waiting for VM to boot..."
sleep 60

# Function to send keys to VM console
send_keys() {
    local keys="$1"
    echo "Sending: $keys"
    # Note: govc doesn't have direct console keystroke injection
    # This would require VNC or VMRC automation
    echo "  (Manual step required - see MANUAL_CONFIGURATION.md)"
}

echo ""
echo "=========================================="
echo "IMPORTANT: Automated console access is not available"
echo "=========================================="
echo ""
echo "VMware vCenter does not provide command-line console access like KVM's 'virsh console'."
echo "You must configure the VM manually using one of these methods:"
echo ""
echo "Method 1: vCenter Web Console (Recommended)"
echo "  1. Open vCenter UI: https://\$GOVC_URL"
echo "  2. Navigate to VM: $VM_NAME"
echo "  3. Click 'Launch Web Console'"
echo "  4. Login: localadmin / password"
echo "  5. Run these commands:"
echo "     edit"
echo "     channel data port eth0 ip $IP netmask 255.255.255.0 gateway $GATEWAY"
echo "     system dns $DNS"
echo "     system hostname manager"
echo "     system organization IBM"
echo "     system country US"
echo "     activate"
echo "     exit"
echo ""
echo "Method 2: ESXi Host Console (Advanced)"
echo "  1. SSH to ESXi host"
echo "  2. Find VM ID: vim-cmd vmsvc/getallvms | grep $VM_NAME"
echo "  3. Open console: vim-cmd vmsvc/console <vmid>"
echo "  4. Follow same steps as Method 1"
echo ""
echo "Method 3: VMware Remote Console (VMRC)"
echo "  1. Install VMRC from VMware"
echo "  2. Connect to VM console"
echo "  3. Follow same steps as Method 1"
echo ""
echo "See MANUAL_CONFIGURATION.md for detailed instructions."
echo "=========================================="

exit 0

# Made with Bob
