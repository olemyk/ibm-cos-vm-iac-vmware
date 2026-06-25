#!/bin/bash
#
# Setup govc environment variables for vCenter access
#
# IMPORTANT: This script must be SOURCED, not executed:
#   ✅ Correct:   source scripts/setup-govc-env.sh
#   ✅ Correct:   . scripts/setup-govc-env.sh
#   ❌ Wrong:     scripts/setup-govc-env.sh
#   ❌ Wrong:     ./scripts/setup-govc-env.sh
#

# Check if script is being sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "❌ ERROR: This script must be SOURCED, not executed!"
    echo ""
    echo "Run it like this:"
    echo "  source scripts/setup-govc-env.sh"
    echo ""
    echo "Or:"
    echo "  . scripts/setup-govc-env.sh"
    exit 1
fi

# Find terraform.tfvars
# Try current directory first
if [ -f "terraform.tfvars" ]; then
    TFVARS="terraform.tfvars"
# Try parent directory (if running from scripts/)
elif [ -f "../terraform.tfvars" ]; then
    TFVARS="../terraform.tfvars"
# Try absolute path based on script location
else
    SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    TFVARS="$SCRIPT_DIR/../terraform.tfvars"
fi

if [ ! -f "$TFVARS" ]; then
    echo "❌ ERROR: terraform.tfvars not found!"
    echo ""
    echo "Searched in:"
    echo "  - ./terraform.tfvars"
    echo "  - ../terraform.tfvars"
    echo "  - $TFVARS"
    echo ""
    echo "Please run this script from the project directory:"
    echo "  cd /path/to/ibm-cos-vm-iac-vcenter"
    echo "  source scripts/setup-govc-env.sh"
    return 1
fi

echo "📄 Using config: $TFVARS"
echo ""

# Extract values from terraform.tfvars
export GOVC_URL=$(grep 'vsphere_server' "$TFVARS" | cut -d'"' -f2)
export GOVC_USERNAME=$(grep 'vsphere_user' "$TFVARS" | cut -d'"' -f2)
export GOVC_PASSWORD=$(grep 'vsphere_password' "$TFVARS" | cut -d'"' -f2)
export GOVC_DATACENTER=$(grep 'vsphere_datacenter' "$TFVARS" | cut -d'"' -f2)
export GOVC_DATASTORE=$(grep 'vsphere_datastore' "$TFVARS" | cut -d'"' -f2)
export GOVC_NETWORK=$(grep 'vsphere_network' "$TFVARS" | cut -d'"' -f2)
CLUSTER=$(grep 'vsphere_cluster' "$TFVARS" | cut -d'"' -f2)
# Resource pool is typically cluster/Resources
export GOVC_RESOURCE_POOL="$CLUSTER/Resources"
export GOVC_INSECURE=true

echo "✅ govc environment variables set:"
echo "   GOVC_URL=$GOVC_URL"
echo "   GOVC_USERNAME=$GOVC_USERNAME"
echo "   GOVC_DATACENTER=$GOVC_DATACENTER"
echo "   GOVC_DATASTORE=$GOVC_DATASTORE"
echo "   GOVC_NETWORK=$GOVC_NETWORK"
echo ""
echo "Test connection:"
echo "   govc about"
echo ""
echo "Upload ISO example:"
echo "   govc datastore.upload -ds=\$GOVC_DATASTORE \\"
echo "     iso/clevos-3.20.1.59-manager-usbiso.iso \\"
echo "     iso/clevos-3.20.1.59-manager-usbiso.iso"

# Made with Bob
