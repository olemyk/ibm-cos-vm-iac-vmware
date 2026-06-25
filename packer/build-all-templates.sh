#!/bin/bash
# Build all IBM COS Packer templates
# This script builds Manager, Accesser, and Slicestor templates sequentially

set -e  # Exit on error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=========================================="
echo "IBM COS Packer Template Builder"
echo "=========================================="
echo ""

# Check if variables file exists
if [ ! -f "variables.pkrvars.hcl" ]; then
    echo "❌ Error: variables.pkrvars.hcl not found"
    echo "Please create it from variables.pkrvars.hcl.example"
    exit 1
fi

# Check if SSH key exists
if [ ! -f "packer_rsa" ]; then
    echo "❌ Error: packer_rsa SSH key not found"
    echo "Please run: ssh-keygen -t rsa -b 4096 -f packer_rsa -N '' -C 'packer@ibm-cos-automation'"
    exit 1
fi

echo "✅ Prerequisites check passed"
echo ""

# Function to build a template
build_template() {
    local template_name=$1
    local template_file=$2
    
    echo "=========================================="
    echo "Building $template_name Template"
    echo "=========================================="
    echo "Start time: $(date)"
    echo ""
    
    if packer build -var-file=variables.pkrvars.hcl "$template_file"; then
        echo ""
        echo "✅ $template_name template built successfully"
        echo "End time: $(date)"
        echo ""
        return 0
    else
        echo ""
        echo "❌ $template_name template build failed"
        echo "End time: $(date)"
        echo ""
        return 1
    fi
}

# Track build results
FAILED_BUILDS=()
SUCCESSFUL_BUILDS=()

# Build Manager template
if build_template "Manager" "cos-manager.pkr.hcl"; then
    SUCCESSFUL_BUILDS+=("Manager")
else
    FAILED_BUILDS+=("Manager")
fi

# Build Accesser template
if build_template "Accesser" "cos-accesser.pkr.hcl"; then
    SUCCESSFUL_BUILDS+=("Accesser")
else
    FAILED_BUILDS+=("Accesser")
fi

# Build Slicestor template
if build_template "Slicestor" "cos-slicestor.pkr.hcl"; then
    SUCCESSFUL_BUILDS+=("Slicestor")
else
    FAILED_BUILDS+=("Slicestor")
fi

# Summary
echo "=========================================="
echo "Build Summary"
echo "=========================================="
echo ""

if [ ${#SUCCESSFUL_BUILDS[@]} -gt 0 ]; then
    echo "✅ Successful builds (${#SUCCESSFUL_BUILDS[@]}):"
    for build in "${SUCCESSFUL_BUILDS[@]}"; do
        echo "   - $build"
    done
    echo ""
fi

if [ ${#FAILED_BUILDS[@]} -gt 0 ]; then
    echo "❌ Failed builds (${#FAILED_BUILDS[@]}):"
    for build in "${FAILED_BUILDS[@]}"; do
        echo "   - $build"
    done
    echo ""
    exit 1
fi

echo "🎉 All templates built successfully!"
echo ""
echo "Templates created:"
echo "   - cos-manager-template"
echo "   - cos-accesser-template"
echo "   - cos-slicestor-template"
echo ""
echo "End time: $(date)"

# Made with Bob
