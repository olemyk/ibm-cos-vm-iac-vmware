# Packer-Terraform Integration Guide

## Overview

This guide explains the complete workflow for deploying IBM Cloud Object Storage on VMware vCenter using Packer templates and Terraform automation.

## Architecture

### Two-Phase Deployment

**Phase 1: Template Creation (Packer)**
- Build VM templates from IBM COS All-in-One ISO
- Configure with SSH keys for automation
- Templates have default IPs (10.33.3.200-202)
- One-time process per COS version

**Phase 2: Infrastructure Deployment (Terraform)**
- Clone VMs from Packer templates
- Reconfigure network to production IPs (10.33.3.203+)
- Sequential deployment to avoid IP conflicts
- Automated via SSH

## Hardware Specifications

Based on IBM documentation: https://www.ibm.com/docs/en/coss/3.20.0?topic=environment-set-virtual-machine-hardware-properties

### Manager Node
- **CPU**: 4 vCPUs
- **RAM**: 16 GB
- **Boot Disk**: 256 GB (Thick Provision Lazy Zeroed)
- **SCSI Controller**: Paravirtual (pvscsi)
- **Network**: vmxnet3

### Accesser Node
- **CPU**: 4 vCPUs
- **RAM**: 16 GB
- **Boot Disk**: 128 GB (Thick Provision Lazy Zeroed)
- **SCSI Controller**: Paravirtual (pvscsi)
- **Network**: vmxnet3

### Slicestor Node
- **CPU**: 2 vCPUs
- **RAM**: 8 GB
- **Boot Disk**: 128 GB (Thick Provision Lazy Zeroed)
- **Data Disks**: 12 x 128 GB (Thick Provision Lazy Zeroed) = 1.5 TB per node
- **SCSI Controller**: Paravirtual (pvscsi)
- **Network**: vmxnet3

## IP Address Scheme

### Template IPs (Packer)
- Manager template: `10.33.3.200`
- Accesser template: `10.33.3.201`
- Slicestor template: `10.33.3.202`

### Production IPs (Terraform)
- Manager: `10.33.3.203`
- Accesser: `10.33.3.204`
- Slicestor 1: `10.33.3.205`
- Slicestor 2: `10.33.3.206`
- Slicestor 3: `10.33.3.207`

## Prerequisites

### Software Requirements
- **Packer**: >= 1.8.0
- **Terraform**: >= 1.0.0
- **govc**: Latest version (for vCenter CLI operations)
- **SSH**: OpenSSH client

### vCenter Requirements
- vCenter Server 7.0 or later
- ESXi hosts with sufficient resources
- Datastore with adequate space:
  - Templates: ~400 GB (Manager 256GB + Accesser 128GB + Slicestor 128GB)
  - Production VMs: ~2.5 TB for 1 Manager + 1 Accesser + 3 Slicestors
- Network with DHCP or static IP range

### ISO File
- IBM COS All-in-One USB ISO: `clevos-3.20.1.59-allinone-usbiso.iso`
- Upload to vCenter datastore (e.g., `[datastore1] iso/`)

## Phase 1: Build Packer Templates

### Step 1: Generate SSH Key

```bash
cd packer
./setup-ssh-key.sh
```

This creates `packer_rsa` and `packer_rsa.pub` for automation.

### Step 2: Configure Packer Variables

Copy and edit the variables file:

```bash
cp variables.pkrvars.hcl.example variables.pkrvars.hcl
vi variables.pkrvars.hcl
```

Required settings:
```hcl
vcenter_server   = "vcenter.example.com"
vcenter_username = "administrator@vsphere.local"
vcenter_password = "your-password"
vcenter_datacenter = "Datacenter"
vcenter_cluster    = "Cluster"
vcenter_datastore  = "datastore1"
vcenter_network    = "VM Network"
vcenter_host       = "esxi01.example.com"  # Optional

# Network configuration for templates
manager_ip  = "10.33.3.200"
accesser_ip = "10.33.3.201"
slicestor_ip = "10.33.3.202"
gateway     = "10.33.3.1"
netmask     = "255.255.255.0"
dns         = "8.8.8.8"

# ISO path in datastore
iso_path = "[datastore1] iso/clevos-3.20.1.59-allinone-usbiso.iso"
```

### Step 3: Build All Templates

```bash
./build-all-templates.sh
```

This builds three templates sequentially:
1. **cos-manager-template** (~17 minutes)
2. **cos-accesser-template** (~17 minutes)
3. **cos-slicestor-template** (~17 minutes)

**Total time**: ~50 minutes

### Step 4: Verify Templates

```bash
govc ls /Datacenter/vm/Templates
```

Expected output:
```
/Datacenter/vm/Templates/cos-manager-template
/Datacenter/vm/Templates/cos-accesser-template
/Datacenter/vm/Templates/cos-slicestor-template
```

Verify SSH access:
```bash
ssh -i packer_rsa localadmin@10.33.3.200 "version"
ssh -i packer_rsa localadmin@10.33.3.201 "version"
ssh -i packer_rsa localadmin@10.33.3.202 "version"
```

## Phase 2: Deploy with Terraform

### Step 1: Configure Terraform Variables

```bash
cd ..  # Back to project root
cp terraform.tfvars.example terraform.tfvars
vi terraform.tfvars
```

Key settings:
```hcl
# vCenter connection
vsphere_server   = "vcenter.example.com"
vsphere_user     = "administrator@vsphere.local"
vsphere_password = "your-password"

# Infrastructure
vsphere_datacenter = "Datacenter"
vsphere_cluster    = "Cluster"
vsphere_datastore  = "datastore1"
vsphere_network    = "VM Network"

# VM folder (will be created)
vm_folder = "COS-System-1"

# Network configuration
base_ip = "10.33.3.203"  # Manager IP
gateway = "10.33.3.1"
netmask = "255.255.255.0"
dns_servers = "8.8.8.8,8.8.4.4"
ntp_servers = "pool.ntp.org"

# COS configuration
num_slicestors = 3
organization_name = "IBM"
country_code = "US"

# Template names (must match Packer output)
cos_manager_template = "cos-manager-template"
cos_accesser_template = "cos-accesser-template"
cos_slicestor_template = "cos-slicestor-template"

# SSH key path (same as Packer)
ssh_private_key_path = "./packer/packer_rsa"
```

### Step 2: Initialize Terraform

```bash
terraform init
```

### Step 3: Plan Deployment

```bash
terraform plan
```

Review the plan:
- 1 VM folder
- 1 Manager VM (4 CPU, 16 GB RAM, 256 GB disk)
- 1 Accesser VM (4 CPU, 16 GB RAM, 128 GB disk)
- 3 Slicestor VMs (2 CPU, 8 GB RAM, 128 GB boot + 12x128 GB data disks each)

### Step 4: Deploy Infrastructure

```bash
terraform apply
```

**Deployment sequence** (automatic):
1. Create VM folder: `COS-System-1`
2. Deploy Manager → Reconfigure to 10.33.3.203 (~5 min)
3. Deploy Accesser → Reconfigure to 10.33.3.204 + connect to Manager (~5 min)
4. Deploy Slicestor 1 → Reconfigure to 10.33.3.205 + connect to Manager (~5 min)
5. Deploy Slicestor 2 → Reconfigure to 10.33.3.206 + connect to Manager (~5 min)
6. Deploy Slicestor 3 → Reconfigure to 10.33.3.207 + connect to Manager (~5 min)

**Total deployment time**: ~25 minutes

### Step 5: Verify Deployment

Check all nodes are accessible:

```bash
# Manager
ssh -i ./packer/packer_rsa localadmin@10.33.3.203 "version"

# Accesser
ssh -i ./packer/packer_rsa localadmin@10.33.3.204 "version"

# Slicestors
ssh -i ./packer/packer_rsa localadmin@10.33.3.205 "version"
ssh -i ./packer/packer_rsa localadmin@10.33.3.206 "version"
ssh -i ./packer/packer_rsa localadmin@10.33.3.207 "version"
```

Check vCenter folder:
```bash
govc ls /Datacenter/vm/COS-System-1
```

## Sequential Deployment Logic

### Why Sequential?

All VMs cloned from templates initially have the same IP addresses:
- Manager clone: 10.33.3.200
- Accesser clone: 10.33.3.201
- Slicestor clones: 10.33.3.202

If deployed simultaneously, IP conflicts occur.

### How It Works

Terraform uses `depends_on` to enforce order:

```hcl
# Manager deploys first
module "cos_manager" { }

# Accesser waits for Manager
module "cos_accesser" {
  depends_on = [module.cos_manager]
}

# Each Slicestor waits for previous
module "cos_slicestor" {
  count = 3
  depends_on = [module.cos_accesser]
}
```

Each deployment:
1. Clone VM from template
2. Wait for SSH at template IP
3. Reconfigure network to new IP
4. Verify new IP is accessible
5. Next VM can deploy

## SSH Configuration Process

### Manager Configuration

Script: `scripts/configure-manager-ssh.sh`

Commands executed via SSH:
```bash
edit
channel data port eth0 ip 10.33.3.203 netmask 255.255.255.0 gateway 10.33.3.1
system dns 8.8.8.8
system ntpservers pool.ntp.org
system hostname manager
system organization IBM
system country US
activate
exit
```

### Accesser/Slicestor Configuration

Scripts: `scripts/configure-accesser-ssh.sh`, `scripts/configure-slicestor-ssh.sh`

Additional command for manager connection:
```bash
manager ip 10.33.3.203
y                    # Accept manager certificate
<enter>              # Skip fingerprint verification
```

## Storage Configuration

### Slicestor Data Disks

Each Slicestor VM has:
- **Boot disk**: 128 GB (from template)
- **Data disks**: 12 x 128 GB = 1.5 TB

Total storage per Slicestor: **1.628 TB**

For 3 Slicestors: **4.884 TB** total storage

All disks use **Thick Provision Lazy Zeroed**:
- Space allocated immediately
- Zeroed on first write
- Better performance than thin provisioning

## Troubleshooting

### Template Build Failures

**Issue**: Packer build times out during installation

**Solution**:
- Increase `boot_wait` in Packer template
- Check ISO is accessible in datastore
- Verify network connectivity

**Issue**: SSH connection fails after build

**Solution**:
- Verify SSH key is correctly embedded in boot command
- Check template IP is accessible from Packer host
- Review Packer logs: `packer build -debug`

### Terraform Deployment Issues

**Issue**: "Template not found"

**Solution**:
```bash
# Verify templates exist
govc ls /Datacenter/vm/Templates

# Check template names match variables
grep cos_.*_template terraform.tfvars
```

**Issue**: IP conflict during deployment

**Solution**:
- Ensure sequential deployment is working (check `depends_on`)
- Verify no other VMs are using template IPs
- Check network configuration

**Issue**: SSH configuration fails

**Solution**:
```bash
# Test SSH key manually
ssh -i ./packer/packer_rsa localadmin@<template_ip> "version"

# Check SSH key permissions
chmod 600 ./packer/packer_rsa

# Review configuration script logs in Terraform output
```

### Network Issues

**Issue**: VMs not accessible after reconfiguration

**Solution**:
- Verify gateway is correct
- Check DNS servers are reachable
- Ensure IP range doesn't conflict with DHCP
- Review network settings in vCenter

## Maintenance

### Updating COS Version

1. Download new All-in-One ISO
2. Upload to vCenter datastore
3. Update `iso_path` in `packer/variables.pkrvars.hcl`
4. Rebuild templates:
   ```bash
   cd packer
   ./build-all-templates.sh
   ```
5. Update `cos_version` in Terraform if needed
6. Deploy new infrastructure or update existing

### Scaling Slicestors

To add more Slicestors:

1. Update `terraform.tfvars`:
   ```hcl
   num_slicestors = 6  # Changed from 3
   ```

2. Apply changes:
   ```bash
   terraform apply
   ```

Terraform will add 3 more Slicestors sequentially.

### Destroying Infrastructure

```bash
# Destroy all VMs
terraform destroy

# Templates remain for future deployments
```

To remove templates:
```bash
govc vm.destroy /Datacenter/vm/Templates/cos-manager-template
govc vm.destroy /Datacenter/vm/Templates/cos-accesser-template
govc vm.destroy /Datacenter/vm/Templates/cos-slicestor-template
```

## Best Practices

### Security

1. **Protect SSH keys**:
   ```bash
   chmod 600 packer/packer_rsa
   # Add to .gitignore
   ```

2. **Use separate keys for production**:
   - Packer key for automation
   - Different key for manual access

3. **Secure Terraform state**:
   - Use remote backend (S3, Terraform Cloud)
   - Enable state encryption

### Performance

1. **Use local datastores** for better I/O performance
2. **Enable VMCI** (restricted mode) as per IBM docs
3. **Use Paravirtual SCSI** controllers
4. **Thick Provision** disks for production

### Monitoring

1. **Track deployment time** to identify bottlenecks
2. **Monitor vCenter resources** during builds
3. **Log SSH configuration** output for debugging
4. **Verify manager connectivity** from Accesser/Slicestor

## Reference

### File Structure

```
ibm-cos-vm-iac-vcenter/
├── packer/
│   ├── cos-manager.pkr.hcl          # Manager template
│   ├── cos-accesser.pkr.hcl         # Accesser template
│   ├── cos-slicestor.pkr.hcl        # Slicestor template
│   ├── variables.pkrvars.hcl        # Packer variables
│   ├── build-all-templates.sh       # Build script
│   ├── setup-ssh-key.sh             # SSH key generator
│   ├── packer_rsa                   # Private key (git-ignored)
│   └── packer_rsa.pub               # Public key
├── scripts/
│   ├── configure-manager-ssh.sh     # Manager SSH config
│   ├── configure-accesser-ssh.sh    # Accesser SSH config
│   └── configure-slicestor-ssh.sh   # Slicestor SSH config
├── modules/
│   ├── cos-manager/                 # Manager Terraform module
│   ├── cos-accesser/                # Accesser Terraform module
│   └── cos-slicestor/               # Slicestor Terraform module
├── main.tf                          # Main Terraform config
├── variables.tf                     # Terraform variables
├── outputs.tf                       # Terraform outputs
└── terraform.tfvars                 # User configuration
```

### Key Commands

```bash
# Packer
packer build -var-file=variables.pkrvars.hcl cos-manager.pkr.hcl
packer build -var-file=variables.pkrvars.hcl cos-accesser.pkr.hcl
packer build -var-file=variables.pkrvars.hcl cos-slicestor.pkr.hcl

# Terraform
terraform init
terraform plan
terraform apply
terraform destroy

# govc
govc ls /Datacenter/vm/Templates
govc vm.info cos-manager-template
govc vm.destroy /path/to/vm

# SSH
ssh -i ./packer/packer_rsa localadmin@<ip> "version"
ssh -i ./packer/packer_rsa localadmin@<ip> "appliance status"
```

## Support

For issues or questions:
1. Check this documentation
2. Review Packer/Terraform logs
3. Consult IBM COS documentation
4. Open an issue in the project repository

---

**Last Updated**: 2026-06-20  
**COS Version**: 3.20.1.59  
**Packer Version**: >= 1.8.0  
**Terraform Version**: >= 1.0.0