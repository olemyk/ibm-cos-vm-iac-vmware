# IBM COS Packer Automation

This directory contains Packer templates for automated creation of IBM Cloud Object Storage (COS) VM templates from the all-in-one ISO.

## Overview

Packer automates the complete installation and configuration process, creating ready-to-use VM templates in vCenter. These templates can then be rapidly cloned by Terraform for production deployments.

## Available Templates

### 1. Manager Template (`cos-manager.pkr.hcl`)
- **Component**: Manager (option 2 in installer)
- **Template Name**: `cos-manager-template`
- **Default IP**: 10.33.3.200
- **Build Time**: ~17 minutes
- **Purpose**: Central management and web interface

### 2. Accesser Template (`cos-accesser.pkr.hcl`)
- **Component**: Accesser (option 1 in installer)
- **Template Name**: `cos-accesser-template`
- **Default IP**: 10.33.3.201
- **Build Time**: ~17 minutes
- **Purpose**: S3 API gateway and data access

### 3. Slicestor Template (`cos-slicestor.pkr.hcl`)
- **Component**: Slicestor (option 3 in installer)
- **Template Name**: `cos-slicestor-template`
- **Default IP**: 10.33.3.202
- **Build Time**: ~17 minutes
- **Purpose**: Data storage and erasure coding

## Prerequisites

1. **Packer Installation**
   ```bash
   # macOS
   brew install packer
   
   # Linux
   wget https://releases.hashicorp.com/packer/1.9.4/packer_1.9.4_linux_amd64.zip
   unzip packer_1.9.4_linux_amd64.zip
   sudo mv packer /usr/local/bin/
   ```

2. **ISO Upload**
   - Upload `clevos-3.20.1.59-allinone-usbiso.iso` to vCenter datastore
   - Default path: `[datastore1] iso/clevos-3.20.1.59-allinone-usbiso.iso`

3. **SSH Key Pair**
   - Dedicated Packer SSH key already created: `packer_rsa` / `packer_rsa.pub`
   - Private key is git-ignored for security

4. **vCenter Access**
   - Administrator credentials
   - Network with DHCP or static IP capability
   - Sufficient storage and compute resources

## Configuration

### Variables File (`variables.pkrvars.hcl`)

```hcl
# vCenter connection
vcenter_server     = "vcenter.example.com"
vcenter_username   = "administrator@vsphere.local"
vcenter_password   = "your-password"
vcenter_datacenter = "Datacenter"
vcenter_cluster    = "Cluster"
vcenter_datastore  = "datastore1"
vcenter_network    = "VM Network"
vcenter_host       = "esxi01.example.com"  # Optional: pin to specific host

# Network configuration
manager_ip   = "10.33.3.200"
accesser_ip  = "10.33.3.201"
slicestor_ip = "10.33.3.202"
gateway      = "10.33.3.1"
dns          = "10.33.3.1"
netmask      = "255.255.255.0"

# ISO path in datastore
iso_path = "[datastore1] iso/clevos-3.20.1.59-allinone-usbiso.iso"

# Organization details
organization = "IBM"
country      = "US"
```

## Usage

### Build Manager Template

```bash
cd packer
packer build -var-file=variables.pkrvars.hcl cos-manager.pkr.hcl
```

### Build Accesser Template

```bash
cd packer
packer build -var-file=variables.pkrvars.hcl cos-accesser.pkr.hcl
```

### Build Slicestor Template

```bash
cd packer
packer build -var-file=variables.pkrvars.hcl cos-slicestor.pkr.hcl
```

### Build All Templates

```bash
cd packer
packer build -var-file=variables.pkrvars.hcl cos-manager.pkr.hcl
packer build -var-file=variables.pkrvars.hcl cos-accesser.pkr.hcl
packer build -var-file=variables.pkrvars.hcl cos-slicestor.pkr.hcl
```

## Build Process

Each build follows these phases:

### Phase 1: Boot and Component Selection (0-2 minutes)
- Wait for boot menu
- Select automatic installation
- Choose disk erasure
- Select component (Manager or Accesser)

### Phase 2: Installation (2-5 minutes)
- Automated OS installation
- Component-specific packages
- System initialization

### Phase 3: Post-Installation Boot (5-7 minutes)
- System boot
- Service initialization
- Login prompt appears

### Phase 4: Network Configuration (7-10 minutes)
- Login as localadmin
- Configure network (IP, gateway, DNS)
- Set hostname
- Configure organization and country

### Phase 5: SSH Key Setup (10-14 minutes)
- Add Packer SSH public key
- Activate configuration (takes ~3 minutes)
- Verify network connectivity (ping gateway)

### Phase 6: SSH Connection and Finalization (14-17 minutes)
- Wait for SSH service
- Connect via SSH (validates configuration)
- Shutdown VM
- Convert to template

## Automation Features

### Fully Automated
- ✅ Boot menu navigation
- ✅ Disk erasure confirmation
- ✅ Component selection
- ✅ Network configuration
- ✅ SSH key authentication setup
- ✅ Template conversion

### No Manual Intervention Required
- No console interaction needed
- No post-installation configuration
- Ready-to-clone templates

### Optimized Timing
- 200-second activation wait (tested and verified)
- Network connectivity verification
- SSH readiness checks

## Output

### Templates Created
- `./vm/Templates/cos-manager-template`
- `./vm/Templates/cos-accesser-template`
- `./vm/Templates/cos-slicestor-template`

### Manifest Files
- `manifest.json` - Manager build details
- `manifest-accesser.json` - Accesser build details
- `manifest-slicestor.json` - Slicestor build details

## Troubleshooting

### Build Fails at SSH Connection
- **Cause**: SSH key not properly configured or activation timeout too short
- **Solution**: Verify `packer_rsa` key exists and matches public key in boot_command

### Build Fails at Component Selection
- **Cause**: Timing issues with boot menu
- **Solution**: Increase `boot_wait` or wait times in boot_command

### Network Not Reachable
- **Cause**: IP configuration didn't apply or network issue
- **Solution**: Check network settings in variables.pkrvars.hcl

### Template Already Exists
- **Cause**: Previous build left template
- **Solution**: Delete template manually or use cleanup script:
  ```bash
  govc vm.destroy "cos-manager-template"
  govc vm.destroy "cos-accesser-template"
  govc vm.destroy "cos-slicestor-template"
  ```

## Key Technical Details

### SSH Authentication
- Uses dedicated Packer SSH key pair
- Public key injected during installation via `sshkeys set` command
- Private key used for SSH connection validation
- Key must be quoted in boot command: `"ssh-rsa AAAA..."`

### IBM COS Appliance Shell
- Custom restricted shell (not standard bash)
- Limited command set: `edit`, `activate`, `sshkeys`, `version`, `appliance`, `poweroff`
- No standard Linux commands: `chmod`, `sudo`, `echo`, etc.
- Shell provisioners not supported

### Boot Command Optimization
- Single edit session (stay in edit mode throughout)
- Extended activation wait (200 seconds)
- Network verification (ping gateway)
- Minimal mode switches

## Next Steps

1. **Test Templates**: Deploy VMs from templates to verify functionality
2. **Update Terraform**: Modify Terraform modules to use templates instead of OVA
3. **Create Slicestor Template**: Add Packer template for Slicestor component
4. **Automate Builds**: Create CI/CD pipeline for template updates

## Benefits

### Time Savings
- **Manual Installation**: 20-30 minutes per VM
- **Packer Template**: 17 minutes once, then instant clones
- **ROI**: Significant time savings for multiple deployments

### Consistency
- Identical configuration every time
- No human error
- Version controlled

### Scalability
- Rapid deployment of multiple VMs
- Parallel builds possible
- Infrastructure as Code

## Files

- `cos-manager.pkr.hcl` - Manager template definition
- `cos-accesser.pkr.hcl` - Accesser template definition
- `cos-slicestor.pkr.hcl` - Slicestor template definition
- `variables.pkrvars.hcl` - Configuration variables (user-specific)
- `variables.pkrvars.hcl.example` - Example configuration
- `packer_rsa` - Private SSH key (git-ignored)
- `packer_rsa.pub` - Public SSH key
- `manifest.json` - Manager build manifest
- `manifest-accesser.json` - Accesser build manifest
- `manifest-slicestor.json` - Slicestor build manifest

## Security Notes

- Private SSH key (`packer_rsa`) is git-ignored
- vCenter credentials should be secured (use environment variables or vault)
- Templates contain SSH public key for automation
- Change default passwords after deployment

## Support

For issues or questions:
1. Check build logs for error messages
2. Review `doc/ISO-INSTALLATION-ANALYSIS.md` for installation details
3. Verify network connectivity and vCenter access
4. Ensure ISO is uploaded and accessible

---

**Created with Packer automation for IBM Cloud Object Storage deployment on VMware vCenter**