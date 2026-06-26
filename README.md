# Infrastructure-as-Code for IBM COS on VMware vCenter

## Scope

This project demonstrates how to deploy IBM Cloud Object Storage System (IBM COS) on VMware vCenter using **Packer templates** and **Terraform** infrastructure-as-code. The deployment uses a two-phase approach:

1. **Phase 1 (Packer)**: Build VM templates from IBM COS All-in-One ISO (one-time, ~50 minutes)
2. **Phase 2 (Terraform)**: Deploy and configure VMs from templates (automated, ~40-45 minutes)

**Important:** This project and the operation of IBM Cloud Object Storage System deployed on VMware vCenter is for evaluation or demonstration purposes only and is not officially supported by IBM.

## 🚀 Key Features

- ✅ **Fully Automated Deployment**: No manual console configuration required
- ✅ **Template-Based**: Fast, consistent VM deployments from Packer templates
- ✅ **Sequential Deployment**: Prevents IP conflicts during network reconfiguration
- ✅ **SSH Automation**: Automatic network configuration and cluster setup
- ✅ **Unique Device Fingerprints**: Each VM gets unique private key via `system rekey`
- ✅ **Production Hardware**: Specs per IBM documentation (Manager: 4 CPU/16GB/128GB, Accesser: 4 CPU/16GB/128GB)
- ✅ **Optimized Storage**: 12 × 16GB data disks per Slicestor (192GB per node, meets minimum requirement)
- ✅ **NTP Configuration**: Automatic time synchronization across cluster

## Architecture

The deployment creates the following components:
- **1 Manager VM**: Central management node (4 vCPU, 16GB RAM, 128GB disk)
- **1-3 Accesser VMs**: S3 API gateways (4 vCPU, 16GB RAM, 128GB disk each)
- **3-6 Slicestor VMs**: Storage nodes with 12 × 16GB data disks each (2 vCPU, 8GB RAM, 320GB total per node)

All VMs are deployed from Packer templates and automatically configured via SSH with unique device fingerprints.

## Prerequisites

### Local Software Requirements

#### Required Tools

1. **Packer** >= 1.15.0 (for building VM templates)
   ```bash
   # macOS
   brew install packer
   
   # Linux
   wget https://releases.hashicorp.com/packer/1.15.4/packer_1.15.4_linux_amd64.zip
   unzip packer_1.15.4_linux_amd64.zip
   sudo mv packer /usr/local/bin/
   
   # Verify
   packer version
   ```

2. **Terraform** >= 1.15 (for infrastructure deployment)
   ```bash
   # macOS
   brew install terraform
   
   # Linux
   wget https://releases.hashicorp.com/terraform/1.6.6/terraform_1.6.6_linux_amd64.zip
   unzip terraform_1.6.6_linux_amd64.zip
   sudo mv terraform /usr/local/bin/
   
   # Verify
   terraform version
   ```

3. **SSH client** (for VM configuration automation)
   ```bash
   # Pre-installed on macOS and most Linux distributions
   # Verify
   ssh -V
   ```

4. **Expect** (for automated SSH interactions)
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

#### Optional Tools

5. **govc** - VMware vSphere CLI (for verification and troubleshooting)
   ```bash
   # macOS
   brew install govmomi/tap/govc
   
   # Linux
   curl -L -o - "https://github.com/vmware/govmomi/releases/latest/download/govc_$(uname -s)_$(uname -m).tar.gz" | tar -C /usr/local/bin -xvzf - govc
   
   # Verify
   govc version
   ```

6. **jq** - JSON processor (for parsing Terraform output)
   ```bash
   # macOS
   brew install jq
   
   # Linux
   sudo dnf install jq  # or apt-get install jq
   ```

### VMware vCenter Requirements

#### vCenter Version
- **VMware vCenter Server** 7.0 or later
- **ESXi Hosts** 7.0 or later

#### Hardware Resources

For a **3-Slicestor deployment** (minimum):

| Resource | Requirement | Notes |
|----------|-------------|-------|
| **vCPU** | 12 cores | 4 (Manager) + 4 (Accesser) + 6 (3×2 Slicestors) |
| **RAM** | 48 GB | 16 (Manager) + 16 (Accesser) + 24 (3×8 Slicestors) |
| **Storage** | ~900 GB | 128 (Manager) + 128 (Accesser) + 640 (3×320 Slicestors) |

For a **6-Slicestor deployment**:

| Resource | Requirement | Notes |
|----------|-------------|-------|
| **vCPU** | 18 cores | 4 (Manager) + 4 (Accesser) + 12 (6×2 Slicestors) |
| **RAM** | 72 GB | 16 (Manager) + 16 (Accesser) + 48 (6×8 Slicestors) |
| **Storage** | ~1.5 TB | 128 (Manager) + 128 (Accesser) + 1280 (6×320 Slicestors) |

**Note**: Storage requirements include:
- Boot disks (128GB per VM)
- Data disks (12 × 16GB per Slicestor = 192GB per Slicestor)
- Template storage (~512GB for all three templates)

#### Network Requirements

- **Static IP Range**: Minimum 10 consecutive IP addresses
  - 3 for templates (e.g., 10.33.3.200-202)
  - 5-9 for production VMs (e.g., 10.33.3.110-118)
- **Gateway**: Accessible from all VMs
- **DNS Servers**: At least one DNS server
- **NTP Servers**: At least one NTP server for time synchronization
- **Network Connectivity**: All VMs must be on the same network segment

#### vCenter Permissions

The vCenter user account must have permissions to:
- ✅ Upload ISO files to datastore
- ✅ Create VMs and templates
- ✅ Clone VMs from templates
- ✅ Create and attach virtual disks
- ✅ Configure VM network settings
- ✅ Power on/off VMs
- ✅ Create and manage VM folders
- ✅ Access VM console (for troubleshooting)

### IBM COS Software

#### Required ISO File

Download the IBM COS All-in-One USB ISO from [IBM Fix Central](https://www.ibm.com/support/fixcentral/):

- **File**: `clevos-3.20.1.59-allinone-usbiso.iso`
- **Size**: ~2.5 GB
- **Type**: Bootable USB ISO with all COS components

Upload to vCenter datastore:
```bash
# Using govc
export GOVC_URL=vcenter.example.com
export GOVC_USERNAME=administrator@vsphere.local
export GOVC_PASSWORD=your-password
export GOVC_INSECURE=true

govc datastore.upload clevos-3.20.1.59-allinone-usbiso.iso iso/clevos-3.20.1.59-allinone-usbiso.iso

# Or use vCenter UI: Storage → Datastore → Upload Files
```

**Note:** Authorization may be required to download these files. Contact your IBM representative for assistance.

#### Tested Versions

This project has been tested with:
- IBM COS version: 3.20.1.59
- VMware vCenter: 7.0 U3
- ESXi: 7.0 U3
- Packer: 1.15.4
- Terraform: 1.6.6

## 📊 Deployment Workflow

For a complete visual overview of the deployment process, see the **[Deployment Workflow Diagram](doc/DEPLOYMENT-WORKFLOW.md)**.

The workflow document includes:
- ✅ Step-by-step visual diagrams with ASCII art
- ✅ Detailed time breakdowns for each phase
- ✅ Network flow diagrams
- ✅ Two-phase configuration explanation
- ✅ Troubleshooting guides
- ✅ Best practices and tips

## Quick Start

### Phase 1: Build Packer Templates (One-Time, ~50 minutes)

#### 1. Clone the Repository

```bash
git clone <repository-url>
cd ibm-cos-vm-iac-vcenter
```

#### 2. Upload ISO to vCenter

Upload the IBM COS All-in-One ISO to your vCenter datastore:

```bash
# Using govc
govc datastore.upload clevos-3.20.1.59-allinone-usbiso.iso iso/clevos-3.20.1.59-allinone-usbiso.iso

# Or use vCenter UI: Storage → Datastore → Upload Files
```

#### 3. Generate SSH Key for Automation

```bash
cd packer
./setup-ssh-key.sh
```

This creates `packer_rsa` and `packer_rsa.pub` for automated configuration.

#### 4. Configure Packer Variables

```bash
cp variables.pkrvars.hcl.example variables.pkrvars.hcl
vi variables.pkrvars.hcl
```

Edit with your vCenter details:

```hcl
vcenter_server     = "vcenter.example.com"
vcenter_username   = "administrator@vsphere.local"
vcenter_password   = "your-password"
vcenter_datacenter = "Datacenter"
vcenter_cluster    = "Cluster"
vcenter_datastore  = "datastore1"
vcenter_network    = "VM Network"

# Template network configuration
manager_ip  = "10.33.3.200"
accesser_ip = "10.33.3.201"
slicestor_ip = "10.33.3.202"
gateway     = "10.33.3.1"
dns         = "8.8.8.8"

# ISO path in datastore
iso_path = "[datastore1] iso/clevos-3.20.1.59-allinone-usbiso.iso"
```

#### 5. Build All Templates

```bash
./build-all-templates.sh
```

This builds three templates sequentially (~17 minutes each):
- `cos-manager-template`
- `cos-accesser-template`
- `cos-slicestor-template`

**Total time**: ~50 minutes

#### 6. Verify Templates

```bash
govc ls /Datacenter/vm/Templates

# Test SSH access
ssh -i packer_rsa localadmin@10.33.3.200 "version"  # Manager
ssh -i packer_rsa localadmin@10.33.3.201 "version"  # Accesser
ssh -i packer_rsa localadmin@10.33.3.202 "version"  # Slicestor
```

### Phase 2: Deploy with Terraform (~25 minutes)

#### 1. Configure Terraform Variables

```bash
cd ..  # Back to project root
cp terraform.tfvars.example terraform.tfvars
vi terraform.tfvars
```

Edit with your configuration:

```hcl
# vCenter Connection
vsphere_server   = "vcenter.example.com"
vsphere_user     = "administrator@vsphere.local"
vsphere_password = "your-password"

# Infrastructure
vsphere_datacenter = "Datacenter"
vsphere_cluster    = "Cluster"
vsphere_datastore  = "datastore1"
vsphere_network    = "VM Network"

# VM Organization
vm_folder = "COS-System-1"

# Network (production IPs, different from templates)
base_ip     = "10.33.3.203"  # Manager IP
gateway     = "10.33.3.1"
dns_servers = "8.8.8.8,8.8.4.4"

# COS Configuration
num_slicestors = 3

# Template names (must match Packer output)
cos_manager_template   = "cos-manager-template"
cos_accesser_template  = "cos-accesser-template"
cos_slicestor_template = "cos-slicestor-template"

# SSH key (same as Packer)
ssh_private_key_path = "./packer/packer_rsa"
```

#### 2. Initialize Terraform

```bash
terraform init
```

#### 3. Review Deployment Plan

```bash
terraform plan
```

Review the resources:
- 1 VM folder
- 1 Manager VM (4 CPU, 16 GB, 128 GB)
- 1 Accesser VM (4 CPU, 16 GB, 128 GB)
- 3 Slicestor VMs (2 CPU, 8 GB, 128 GB + 12×16 GB data disks)

#### 4. Deploy Infrastructure

```bash
terraform apply
```

Deployment sequence (automatic):
1. Manager → Reconfigure to 10.33.3.110 + generate unique key (~8-10 min)
2. Accesser → Reconfigure to 10.33.3.111 + generate unique key + connect to Manager (~12 min)
3. Slicestor 1 → Reconfigure to 10.33.3.112 + generate unique key + connect to Manager (~12 min)
4. Slicestor 2 → Reconfigure to 10.33.3.113 + generate unique key + connect to Manager (~12 min)
5. Slicestor 3 → Reconfigure to 10.33.3.114 + generate unique key + connect to Manager (~12 min)

**Total time**: ~40-45 minutes

**Note**: Each VM gets a unique device fingerprint via `system rekey` command to prevent duplicate device issues.

#### 5. Verify Deployment

```bash
# Check all nodes
ssh -i ./packer/packer_rsa localadmin@10.33.3.110 "version"  # Manager
ssh -i ./packer/packer_rsa localadmin@10.33.3.111 "version"  # Accesser
ssh -i ./packer/packer_rsa localadmin@10.33.3.112 "version"  # Slicestor 1
ssh -i ./packer/packer_rsa localadmin@10.33.3.113 "version"  # Slicestor 2
ssh -i ./packer/packer_rsa localadmin@10.33.3.114 "version"  # Slicestor 3

# Verify unique fingerprints
for ip in 10.33.3.110 10.33.3.111 10.33.3.112 10.33.3.113 10.33.3.114; do
  echo "=== $ip ==="
  ssh -i ./packer/packer_rsa localadmin@$ip "system fingerprint"
done

# Check vCenter folder
govc ls /Datacenter/vm/COS-System-1
```

#### 6. Access the Manager UI

Once deployment is complete, access the Manager UI:

```
https://10.33.3.110
```

Default credentials: `localadmin` / `password`

Complete the first-time setup as described in the [IBM COS documentation](https://www.ibm.com/docs/en/coss/3.20.1?topic=administration-first-time-setup).

**Important**: You must approve all devices (Accesser and Slicestors) in the Manager UI before they can be used. See [Device Approval Guide](scripts/approve-devices.md) for details.

## Deployment Architecture

### Two-Phase Deployment

#### Phase 1: Packer Templates (One-Time)
- **Purpose**: Create reusable VM templates from ISO
- **Duration**: ~50 minutes (one-time setup)
- **Output**: Three templates with pre-configured SSH access
- **Template IPs**: 10.33.3.200-202 (fixed, for template use only)

#### Phase 2: Terraform Deployment (Repeatable)
- **Purpose**: Clone templates and deploy production systems
- **Duration**: ~40-45 minutes per deployment
- **Process**: Sequential deployment with automatic network reconfiguration and unique key generation
- **Production IPs**: Configurable via `base_ip` variable

### Network Configuration

#### Template Network (Packer Phase)
Fixed IPs for template creation:

| Template | IP Address | Purpose |
|----------|------------|---------|
| Manager Template | 10.33.3.200 | Template with SSH enabled |
| Accesser Template | 10.33.3.201 | Template with SSH enabled |
| Slicestor Template | 10.33.3.202 | Template with SSH enabled |

#### Production Network (Terraform Phase)
Sequential IP addressing based on `base_ip` variable:

| Component | IP Address | Description |
|-----------|------------|-------------|
| Manager | `base_ip` | Central management node |
| Accesser 1 | `base_ip + 1` | S3 API gateway |
| Slicestor 1 | `base_ip + 2` | Storage node 1 |
| Slicestor 2 | `base_ip + 3` | Storage node 2 |
| Slicestor 3 | `base_ip + 4` | Storage node 3 |

Example with `base_ip = "10.33.3.110"`:
- Manager: 10.33.3.110
- Accesser 1: 10.33.3.111
- Slicestor 1: 10.33.3.112
- Slicestor 2: 10.33.3.113
- Slicestor 3: 10.33.3.114

**Important**: Ensure your network has these IP addresses available. Template IPs (10.33.3.200-202) and production IPs must not conflict.

### VM Specifications (Production Standards)

| Component | vCPU | RAM | Boot Disk | Data Disks | Total Storage | Purpose |
|-----------|------|-----|-----------|------------|---------------|---------|
| Manager | 4 | 16 GB | 128 GB | - | 128 GB | Management, monitoring, UI |
| Accesser | 4 | 16 GB | 128 GB | - | 128 GB | S3 API endpoint |
| Slicestor | 2 | 8 GB | 128 GB | 12 × 16 GB | 320 GB | Storage with data disks |

**Note**: Specifications follow IBM COS production requirements. Templates are built with these specs and cloned VMs inherit them.

### Storage Configuration

Each Slicestor node includes:
- **Boot Disk**: 128 GB (OS and system)
- **Data Disks**: 12 × 16 GB (thick provisioned, lazy zeroed)
- **Total Storage**: 320 GB per Slicestor (128 GB boot + 192 GB data)
- **Minimum Requirement**: 12 disks required for storage pool width 3

**Storage Capacity by Deployment Size:**
- **3 Slicestors**: 576 GB raw data storage (3 × 192 GB)
- **6 Slicestors**: 1,152 GB raw data storage (6 × 192 GB)

**Note**: The 12 × 16GB configuration meets IBM COS minimum requirement of 12 disks per Slicestor for storage pool width 3, while conserving datastore space compared to larger disk sizes.

### Deployment Process

#### Packer Phase (One-Time)
1. **ISO Upload**: Upload COS ISO to vCenter datastore
2. **SSH Key Generation**: Create `packer_rsa` key pair
3. **Template Build**: Packer automates ISO installation
4. **SSH Configuration**: Enable SSH with public key
5. **Template Creation**: Convert VMs to templates

#### Terraform Phase (Repeatable)
1. **VM Folder Creation**: Organize VMs in vCenter
2. **Template Cloning**: Clone VMs from Packer templates
3. **Sequential Deployment**: Deploy one component at a time
4. **Network Reconfiguration**: SSH scripts change IPs from template to production
5. **Manager Registration**: Accesser and Slicestors connect to Manager
6. **Verification**: Automated health checks

### Sequential Deployment Strategy

To prevent IP conflicts during network reconfiguration:

```
Manager (10.33.3.200 → 10.33.3.203)
  ↓ depends_on
Accesser (10.33.3.201 → 10.33.3.204)
  ↓ depends_on
Slicestor 1 (10.33.3.202 → 10.33.3.205)
  ↓ depends_on
Slicestor 2 (10.33.3.202 → 10.33.3.206)
  ↓ depends_on
Slicestor 3 (10.33.3.202 → 10.33.3.207)
```

Each VM is fully reconfigured before the next one deploys.

## Scaling

### Adding More Slicestors

To deploy with 6 Slicestor nodes instead of 3:

```hcl
# In terraform.tfvars
num_slicestors = 6
```

This will create:
- Manager: `base_ip` (10.33.3.203)
- Accesser: `base_ip + 1` (10.33.3.204)
- Slicestor 1-6: `base_ip + 2` through `base_ip + 7` (10.33.3.205-210)

**Storage Capacity**: 6 nodes × 1.66 TB = ~10 TB raw storage

### Multiple Deployments

To deploy multiple COS systems, use different VM folders and IP ranges:

**System 1**:
```hcl
vm_folder = "COS-System-1"
base_ip   = "10.33.3.203"
```

**System 2**:
```hcl
vm_folder = "COS-System-2"
base_ip   = "10.33.3.213"  # Different IP range
```

Each system uses the same Packer templates but deploys to different folders with different IPs.

## Management Commands

### View Deployment Status

```bash
terraform show
```

### View Outputs

```bash
terraform output
```

Shows Manager URL and IP addresses of all components.

### Destroy the Deployment

```bash
terraform destroy
```

Type `yes` when prompted. This removes all VMs and the VM folder.

**Note**: Packer templates are preserved and can be reused for future deployments.

### Rebuild Templates

If you need to rebuild templates (e.g., for a new COS version):

```bash
cd packer
./build-all-templates.sh
```

This rebuilds all three templates with the latest ISO.

### Update Configuration

1. Modify `terraform.tfvars`
2. Run `terraform plan` to preview changes
3. Run `terraform apply` to apply changes

**Note:** Network changes require VM recreation due to SSH reconfiguration.

## Troubleshooting

### Packer Build Failures

**Problem**: Packer build fails during ISO installation

**Solutions**:
1. Verify ISO path in `variables.pkrvars.hcl`
2. Check ISO is uploaded to datastore: `govc datastore.ls iso/`
3. Verify network connectivity from vCenter to template IPs
4. Check vCenter task history for errors
5. Increase boot_wait if installation is slow

**Problem**: SSH timeout during Packer build

**Solutions**:
1. Verify template IP is accessible: `ping 10.33.3.200`
2. Check SSH key was generated: `ls -la packer/packer_rsa*`
3. Verify boot commands completed successfully (check VM console)
4. Increase communicator timeout in Packer template

### Terraform Deployment Failures

**Problem**: Template not found

**Solutions**:
1. Verify templates exist: `govc ls /Datacenter/vm/Templates`
2. Check template names match `terraform.tfvars`
3. Rebuild templates if missing: `cd packer && ./build-all-templates.sh`

**Problem**: SSH connection fails during reconfiguration

**Solutions**:
1. Verify SSH key path: `ls -la ./packer/packer_rsa`
2. Check template IP is accessible before deployment
3. Verify VM is powered on in vCenter
4. Check VM console for boot errors
5. Test manual SSH: `ssh -i ./packer/packer_rsa localadmin@10.33.3.200`

**Problem**: IP conflict during deployment

**Solutions**:
1. Ensure template IPs (10.33.3.200-202) are not in use
2. Ensure production IPs (base_ip+) are not in use
3. Check no other VMs are using these IPs
4. Verify sequential deployment is working (check depends_on)

### Network Reconfiguration Issues

**Problem**: VM loses connectivity after reconfiguration

**Solutions**:
1. Check gateway is correct in `terraform.tfvars`
2. Verify DNS servers are accessible
3. Check network configuration: `ssh -i ./packer/packer_rsa localadmin@<IP> "show channel"`
4. Review SSH script output for errors
5. Manually reconfigure via vCenter console if needed

**Problem**: Manager IP configuration fails on Accesser/Slicestor

**Solutions**:
1. Verify Manager is accessible: `ping <manager-ip>`
2. Check Manager is fully configured before Accesser/Slicestor deploy
3. Review SSH script output for certificate errors
4. Manually configure: `ssh -i ./packer/packer_rsa localadmin@<IP>` then run `manager ip <manager-ip>`

### Resource Constraints

**Problem**: Insufficient resources in vCenter

**Solutions**:
1. Check cluster resource availability
2. Verify datastore has sufficient space (~2 TB for 3 Slicestors)
3. Reduce number of Slicestors: `num_slicestors = 3`
4. Check vCenter resource pools and limits

**Problem**: Datastore space issues

**Solutions**:
1. Each Slicestor needs ~1.66 TB (128 GB boot + 12×128 GB data)
2. Templates need ~512 GB total
3. Ensure datastore has sufficient free space
4. Consider using thin provisioning for testing (not recommended for production)

### Debug Mode

Enable detailed logging:

```bash
# Packer
PACKER_LOG=1 packer build -var-file=variables.pkrvars.hcl cos-manager.pkr.hcl

# Terraform
TF_LOG=DEBUG terraform apply
```

### Manual Recovery

If automated deployment fails, you can manually configure VMs:

1. **Access VM Console**: vCenter UI → VM → Launch Web Console
2. **Login**: `localadmin` / `password`
3. **Configure Network**:
   ```
   edit
   channel data port eth0 ip <NEW_IP> netmask 255.255.255.0 gateway <GATEWAY>
   system dns <DNS>
   system hostname <HOSTNAME>
   activate
   ```
4. **Configure Manager IP** (Accesser/Slicestor only):
   ```
   edit
   manager ip <MANAGER_IP>
   y
   <enter>
   activate
   ```

## Project Structure

```
ibm-cos-vm-iac-vmware/
├── README.md                       # This file
├── CHANGELOG.md                    # Version history
├── LICENSE                         # Apache 2.0
├── versions.tf                     # Terraform version constraints
├── variables.tf                    # Variable definitions
├── main.tf                         # Main Terraform configuration
├── outputs.tf                      # Output definitions
├── terraform.tfvars.example        # Example variables (safe to commit)
├── doc/                            # Supplementary documentation
│   ├── DEPLOYMENT-WORKFLOW.md      # Visual deployment diagram
│   ├── PACKER_TERRAFORM_INTEGRATION.md
│   ├── PACKER_AUTOMATION.md
│   ├── AUTOMATION_OPTIONS.md
│   ├── ISO_AUTOMATION.md
│   ├── ISO-INSTALLATION-ANALYSIS.md
│   ├── KVM_VS_VMWARE.md
│   ├── MANUAL_CONFIGURATION.md
│   ├── MULTI-ACCESSER-SUPPORT.md
│   ├── NEXT_STEPS.md
│   ├── SYSTEM-REKEY-FIX.md
│   └── Iso-install/                # Installation screenshots
├── ova/                            # OVA placeholder (binaries git-ignored)
│   └── README.md
├── iso/                            # ISO placeholder (binaries git-ignored)
│   └── README.md
├── packer/                         # Packer templates for VM template creation
│   ├── cos-manager.pkr.hcl
│   ├── cos-accesser.pkr.hcl
│   ├── cos-slicestor.pkr.hcl
│   ├── variables.pkrvars.hcl.example
│   ├── build-all-templates.sh
│   ├── setup-ssh-key.sh
│   └── README.md
├── scripts/                        # SSH-based post-deploy configuration scripts
│   ├── configure-manager.expect
│   ├── configure-accesser.expect
│   ├── configure-slicestor.expect
│   ├── configure-vms.sh
│   └── ...
└── modules/                        # Terraform modules
    ├── cos-manager/
    ├── cos-accesser/
    └── cos-slicestor/
```

## Security Considerations

1. **Credentials**: Store vCenter credentials securely
   - Use environment variables: `TF_VAR_vsphere_password`
   - Use Terraform Cloud/Enterprise for remote state
   - Never commit `terraform.tfvars` with real credentials

2. **Network Security**: 
   - Use private networks when possible
   - Configure firewall rules appropriately
   - Change default COS passwords after deployment

3. **State Files**:
   - Terraform state contains sensitive data
   - Use remote state with encryption
   - Add `terraform.tfstate*` to `.gitignore`

## Contributing

Pull requests are welcome! Please ensure:

1. Code follows existing style and conventions
2. All scripts are tested
3. Documentation is updated
4. Commit messages are descriptive

## License

All source files must include a Copyright and License header. The SPDX license header is preferred.

```text
#
# Copyright 2024- IBM Inc. All rights reserved
# SPDX-License-Identifier: Apache2.0
#
```

See [LICENSE](LICENSE) for full license text.

## Support

This project is provided as-is for evaluation and demonstration purposes. For production deployments and official support, please contact IBM.

## Additional Resources

- [IBM Cloud Object Storage Documentation](https://www.ibm.com/docs/en/coss)
- [Terraform vSphere Provider Documentation](https://registry.terraform.io/providers/hashicorp/vsphere/latest/docs)
- [IBM Fix Central](https://www.ibm.com/support/fixcentral/)

## Acknowledgments

This project is based on the original [ibm-cos-vm-iac](https://github.com/hseipp/ibm-cos-vm-iac) project for KVM deployments, adapted for VMware vCenter with Terraform.