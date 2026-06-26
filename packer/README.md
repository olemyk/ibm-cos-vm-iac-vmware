# Packer Templates for IBM COS

This directory contains Packer templates for creating IBM COS VM templates from the All-in-One USB ISO file.

## Overview

Using the All-in-One USB ISO file enables **full automation** of IBM COS deployment:

1. **Packer** creates pre-configured VM templates from a single ISO file
2. **Terraform** clones templates to deploy multiple VMs instantly
3. **No manual console configuration** required
4. **Unique device fingerprints** generated automatically via `system rekey`

## Prerequisites

### Local Software Requirements

#### 1. Packer (Required)

**Version**: >= 1.15.0 (tested with 1.15.4)

```bash
# macOS
brew install packer

# Linux (RHEL/CentOS/Fedora)
wget https://releases.hashicorp.com/packer/1.15.4/packer_1.15.4_linux_amd64.zip
unzip packer_1.15.4_linux_amd64.zip
sudo mv packer /usr/local/bin/
chmod +x /usr/local/bin/packer

# Linux (Ubuntu/Debian)
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
sudo apt-get update && sudo apt-get install packer

# Verify installation
packer version
```

#### 2. govc - VMware vSphere CLI (Required)

**Purpose**: Upload ISO files and verify templates

```bash
# macOS
brew install govmomi/tap/govc

# Linux
curl -L -o - "https://github.com/vmware/govmomi/releases/latest/download/govc_$(uname -s)_$(uname -m).tar.gz" | tar -C /usr/local/bin -xvzf - govc
chmod +x /usr/local/bin/govc

# Verify installation
govc version
```

#### 3. SSH Client (Required)

**Purpose**: Packer uses SSH to configure VMs

```bash
# Pre-installed on macOS and most Linux distributions
# Verify
ssh -V
```

#### 4. Expect (Required for Terraform phase)

**Purpose**: Automated SSH interactions during deployment

```bash
# macOS
brew install expect

# Linux (RHEL/CentOS/Fedora)
sudo dnf install expect

# Linux (Ubuntu/Debian)
sudo apt-get install expect

# Verify
expect -v
```

### VMware vCenter Requirements

#### vCenter Access
- **vCenter Server**: 7.0 or later
- **ESXi Hosts**: 7.0 or later
- **Network Access**: Workstation must reach vCenter API and VM network

#### vCenter Permissions

The vCenter user account must have permissions to:
- ✅ Upload files to datastore
- ✅ Create VMs
- ✅ Configure VM hardware (CPU, RAM, disks, network)
- ✅ Power on/off VMs
- ✅ Convert VMs to templates
- ✅ Create folders in VM inventory

#### Hardware Resources for Template Building

| Resource | Requirement | Notes |
|----------|-------------|-------|
| **Datastore Space** | ~512 GB | For all three templates |
| **Network IPs** | 3 static IPs | 10.33.3.200-202 (configurable) |
| **Build Time** | ~50 minutes | Sequential build of 3 templates |

**Template Sizes:**
- Manager Template: ~128 GB
- Accesser Template: ~128 GB
- Slicestor Template: ~256 GB (includes 12 data disks)

### IBM COS Software

#### Required ISO File

Download from [IBM Fix Central](https://www.ibm.com/support/fixcentral/):

- **File**: `clevos-3.20.1.59-allinone-usbiso.iso`
- **Size**: ~2.5 GB
- **Type**: Bootable USB ISO with all COS components (Manager, Accesser, Slicestor)

**Note**: Authorization may be required. Contact your IBM representative for access.

### 2. Upload ISO Files to vCenter

Upload the USB ISO files to your vCenter datastore:

```bash
# Using govc
export GOVC_URL=vcsa.olemyk.com
export GOVC_USERNAME=administrator@vsphere.local
export GOVC_PASSWORD=yourpassword
export GOVC_INSECURE=true

# Upload Manager ISO
govc datastore.upload -ds=datastore1 \
  clevos-3.20.1.59-manager-usbiso.iso \
  iso/clevos-3.20.1.59-manager-usbiso.iso

# Upload Slicestor ISO
govc datastore.upload -ds=datastore1 \
  clevos-3.20.1.59-slicestor-usbiso.iso \
  iso/clevos-3.20.1.59-slicestor-usbiso.iso
```

Or upload via vCenter UI:
1. Navigate to Storage → datastore1
2. Click "Upload Files"
3. Create `iso` folder if it doesn't exist
4. Upload ISO files

### 3. Test Boot Process (Important!)

Before running Packer, **manually test the ISO boot process** to determine exact boot commands:

```bash
# Create test VM
govc vm.create -on=false \
  -c=2 -m=4096 \
  -disk=50GB \
  -net="VM Network" \
  -iso="[datastore1] iso/clevos-3.20.1.59-manager-usbiso.iso" \
  test-cos-boot

# Power on
govc vm.power -on test-cos-boot

# Open console in vCenter UI and document:
# 1. What boot menu appears?
# 2. What options are available?
# 3. How long does it take to boot?
# 4. What prompts appear?
# 5. Can you pass kernel parameters?
```

**Document your findings** and update the `boot_command` in the Packer template accordingly.

## Configuration

### 1. Copy Variables File

```bash
cp variables.pkrvars.hcl.example variables.pkrvars.hcl
```

### 2. Edit Variables

Edit `variables.pkrvars.hcl` with your environment details:

```hcl
vcenter_server     = "vcsa.olemyk.com"
vcenter_username   = "administrator@vsphere.local"
vcenter_password   = "your-password"

vcenter_datacenter = "Datacenter"
vcenter_cluster    = "Cluster"
vcenter_datastore  = "datastore1"
vcenter_network    = "VM Network"

manager_ip = "10.33.3.200"
gateway    = "10.33.3.1"
dns        = "10.33.3.1"
```

### 3. Adjust Boot Commands

**Critical Step**: Update the `boot_command` in `cos-manager.pkr.hcl` based on your boot process testing.

The current template includes placeholder boot commands that need to be adjusted:

```hcl
boot_command = [
  # TODO: Adjust these based on actual boot menu
  "<wait10>",
  "<enter><wait30>",
  "localadmin<enter><wait5>",
  "password<enter><wait10>",
  # ... network configuration commands
]
```

## Usage

### Build Manager Template

```bash
# Validate template
packer validate -var-file=variables.pkrvars.hcl cos-manager.pkr.hcl

# Build template
packer build -var-file=variables.pkrvars.hcl cos-manager.pkr.hcl
```

This will:
1. Create a new VM in vCenter
2. Boot from Manager USB ISO
3. Send automated boot commands
4. Configure network settings
5. Convert to template
6. Template will be available as `cos-manager-template`

### Build Slicestor Template

```bash
# TODO: Create cos-slicestor.pkr.hcl template
# Similar to Manager but with:
# - Different ISO
# - Different hostname
# - 12 additional data disks
```

## Troubleshooting

### Boot Commands Not Working

If Packer fails during boot:

1. **Check timing**: Adjust `<wait>` values in boot_command
2. **Verify boot menu**: Ensure keystrokes match actual boot menu
3. **Test manually**: Boot a VM manually and document exact keystrokes
4. **Enable VNC**: Add VNC to see what Packer is doing:
   ```hcl
   vnc_over_websocket = true
   insecure_connection = true
   ```

### SSH Timeout

If Packer times out waiting for SSH:

1. **Check network config**: Verify IP, gateway, DNS are correct
2. **Increase timeout**: Adjust `ssh_timeout` in template
3. **Verify SSH service**: Ensure SSH is enabled in COS VM
4. **Check firewall**: Ensure vCenter can reach VM IP

### Template Not Created

If template creation fails:

1. **Check permissions**: Ensure vCenter user has template creation rights
2. **Verify folder**: Ensure "Templates" folder exists
3. **Check datastore space**: Ensure enough space for template

## Integration with Terraform

Once templates are created, update Terraform to use them:

### Option 1: Clone from Template

```hcl
resource "vsphere_virtual_machine" "manager" {
  name = "COS1-Manager"
  
  clone {
    template_uuid = data.vsphere_virtual_machine.manager_template.id
  }
  
  # Customize per-VM settings
  # ...
}

data "vsphere_virtual_machine" "manager_template" {
  name          = "cos-manager-template"
  datacenter_id = data.vsphere_datacenter.dc.id
}
```

### Option 2: Linked Clones (Faster)

```hcl
clone {
  template_uuid = data.vsphere_virtual_machine.manager_template.id
  linked_clone  = true
}
```

## Workflow Comparison

### Before (OVA + Manual Config)
```
terraform apply (5 min) → Manual console config (20 min) = 25 min total
```

### After (Packer + Terraform)
```
# One-time setup
packer build (30 min) → Creates templates

# Every deployment
terraform apply (5 min) → Fully configured VMs = 5 min total
```

## Next Steps

1. ✅ Test ISO boot process manually
2. ✅ Document boot menu and commands
3. ✅ Update boot_command in Packer template
4. ✅ Build Manager template with Packer
5. ✅ Create Slicestor template
6. ✅ Update Terraform to use templates
7. ✅ Enjoy fully automated deployments!

## Files

- `cos-manager.pkr.hcl` - Packer template for Manager VM
- `variables.pkrvars.hcl.example` - Example variables file
- `README.md` - This file

## Resources

- [Packer Documentation](https://www.packer.io/docs)
- [vSphere ISO Builder](https://www.packer.io/plugins/builders/vsphere/vsphere-iso)
- [Boot Commands](https://www.packer.io/docs/builders/virtualbox/iso#boot-command)