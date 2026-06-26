# Full Automation with USB ISO Files 🎉

## Game Changer: USB ISO Files Available!

You have access to USB ISO files:
- `clevos-3.20.1.59-manager-usbiso.iso` (1.62 GB)
- `clevos-3.20.1.59-slicestor-usbiso.iso` (1.42 GB)
- `clevos-3.20.1.59-allinone-usbiso.iso` (5.89 GB)

**This enables FULL AUTOMATION** using Packer-style boot commands!

## Why ISO Files Enable Automation

### OVA Limitation
- OVA files boot directly into the OS
- No boot menu or GRUB to intercept
- Cannot inject boot parameters
- Requires manual console configuration

### ISO Advantage ✅
- ISO files have a **boot menu** or **installer**
- Can send **boot commands** during installation
- Can pass **kernel parameters** for network configuration
- **Packer can automate** the entire installation process

## Solution: Packer + Terraform Workflow

### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│ Phase 1: Packer (One-Time Template Creation)                │
├─────────────────────────────────────────────────────────────┤
│ 1. Boot from USB ISO                                        │
│ 2. Send boot commands with network config                   │
│ 3. Automated installation with pre-configuration            │
│ 4. Export as VM template or OVA                             │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ Phase 2: Terraform (Repeatable Deployment)                  │
├─────────────────────────────────────────────────────────────┤
│ 1. Clone from Packer-created template                       │
│ 2. Customize per-VM settings (IP, hostname)                 │
│ 3. Deploy multiple VMs instantly                            │
│ 4. All VMs pre-configured and ready                         │
└─────────────────────────────────────────────────────────────┘
```

## Implementation Plan

### Option A: Packer with Boot Commands (Recommended)

Create Packer templates that:
1. Boot from USB ISO
2. Send automated keystrokes during boot
3. Configure network during installation
4. Create VM templates for Terraform

### Option B: Terraform with ISO + Boot Commands

Use Terraform directly with ISO files and boot commands (similar to Packer but in Terraform).

## Packer Template Example

### File: `packer/cos-manager.pkr.hcl`

```hcl
packer {
  required_plugins {
    vsphere = {
      version = ">= 2.2.0"
      source  = "github.com/hashicorp/vsphere"
    }
  }
}

variable "vcenter_server" {
  type = string
}

variable "vcenter_username" {
  type = string
}

variable "vcenter_password" {
  type      = string
  sensitive = true
}

variable "manager_ip" {
  type    = string
  default = "10.33.3.200"
}

variable "gateway" {
  type    = string
  default = "10.33.3.1"
}

variable "dns" {
  type    = string
  default = "10.33.3.1"
}

source "vsphere-iso" "cos-manager" {
  # vCenter connection
  vcenter_server      = var.vcenter_server
  username            = var.vcenter_username
  password            = var.vcenter_password
  insecure_connection = true

  # VM location
  datacenter = "Datacenter"
  cluster    = "Cluster"
  datastore  = "datastore1"
  folder     = "Templates"

  # VM configuration
  vm_name       = "cos-manager-template"
  guest_os_type = "other3xLinux64Guest"
  CPUs          = 2
  RAM           = 4096
  disk_controller_type = ["pvscsi"]
  
  storage {
    disk_size             = 50000
    disk_thin_provisioned = true
  }

  network_adapters {
    network      = "VM Network"
    network_card = "vmxnet3"
  }

  # ISO configuration
  iso_paths = [
    "[datastore1] iso/clevos-3.20.1.59-manager-usbiso.iso"
  ]

  # Boot configuration - THIS IS THE KEY!
  boot_wait = "10s"
  
  boot_command = [
    # Wait for boot menu
    "<wait10>",
    # Select installation option (adjust based on actual boot menu)
    "<enter><wait>",
    # Wait for login prompt
    "<wait30>",
    # Login
    "localadmin<enter><wait>",
    "password<enter><wait5>",
    # Configure network
    "edit<enter><wait>",
    "channel data port eth0 ip ${var.manager_ip} netmask 255.255.255.0 gateway ${var.gateway}<enter><wait>",
    "system dns ${var.dns}<enter><wait>",
    "system hostname manager<enter><wait>",
    "system organization IBM<enter><wait>",
    "system country US<enter><wait>",
    "activate<enter><wait>",
    "exit<enter><wait>",
  ]

  # SSH configuration for provisioning
  ssh_username = "localadmin"
  ssh_password = "password"
  ssh_timeout  = "20m"

  # Shutdown command
  shutdown_command = "sudo shutdown -h now"
}

build {
  sources = ["source.vsphere-iso.cos-manager"]

  # Optional: Run additional provisioning
  provisioner "shell" {
    inline = [
      "echo 'Manager template created successfully'",
      "ip addr show"
    ]
  }

  # Convert to template
  post-processor "vsphere-template" {
    host     = var.vcenter_server
    username = var.vcenter_username
    password = var.vcenter_password
    insecure = true
  }
}
```

### File: `packer/cos-slicestor.pkr.hcl`

```hcl
# Similar structure but for Slicestor
# Key differences:
# - Different ISO: clevos-3.20.1.59-slicestor-usbiso.iso
# - Different IP: parameterized
# - Different hostname: slicestor
# - Add 12 data disks
```

## Terraform Integration

Once Packer creates templates, Terraform becomes simple:

### File: `main-with-templates.tf`

```hcl
# Clone from Packer-created template
resource "vsphere_virtual_machine" "manager" {
  name             = "COS1-Manager"
  resource_pool_id = data.vsphere_resource_pool.pool.id
  datastore_id     = data.vsphere_datastore.datastore.id

  num_cpus = 2
  memory   = 4096

  # Clone from template created by Packer
  clone {
    template_uuid = data.vsphere_virtual_machine.manager_template.id
    
    customize {
      linux_options {
        host_name = "manager"
        domain    = "local"
      }

      network_interface {
        ipv4_address = var.manager_ip
        ipv4_netmask = 24
      }

      ipv4_gateway = var.gateway
      dns_server_list = [var.dns]
    }
  }

  network_interface {
    network_id = data.vsphere_network.network.id
  }

  disk {
    label = "disk0"
    size  = 50
  }
}

data "vsphere_virtual_machine" "manager_template" {
  name          = "cos-manager-template"
  datacenter_id = data.vsphere_datacenter.dc.id
}
```

## Complete Workflow

### Step 1: Upload ISO Files to vCenter

```bash
# Upload ISO files to datastore
govc datastore.upload -ds=datastore1 \
  clevos-3.20.1.59-manager-usbiso.iso \
  iso/clevos-3.20.1.59-manager-usbiso.iso

govc datastore.upload -ds=datastore1 \
  clevos-3.20.1.59-slicestor-usbiso.iso \
  iso/clevos-3.20.1.59-slicestor-usbiso.iso
```

### Step 2: Create Templates with Packer (One-Time)

```bash
cd packer

# Create Manager template
packer build \
  -var="vcenter_server=vcsa.olemyk.com" \
  -var="vcenter_username=administrator@vsphere.local" \
  -var="vcenter_password=yourpassword" \
  -var="manager_ip=10.33.3.200" \
  -var="gateway=10.33.3.1" \
  -var="dns=10.33.3.1" \
  cos-manager.pkr.hcl

# Create Slicestor template
packer build \
  -var="vcenter_server=vcsa.olemyk.com" \
  -var="vcenter_username=administrator@vsphere.local" \
  -var="vcenter_password=yourpassword" \
  -var="slicestor_ip=10.33.3.202" \
  -var="gateway=10.33.3.1" \
  -var="dns=10.33.3.1" \
  cos-slicestor.pkr.hcl
```

### Step 3: Deploy with Terraform (Repeatable)

```bash
cd terraform
terraform init
terraform apply
```

**Result**: Fully automated deployment! 🎉

## Advantages of ISO Approach

| Feature | OVA Files | USB ISO Files |
|---------|-----------|---------------|
| Boot Commands | ❌ No | ✅ Yes |
| Packer Support | ⚠️ Limited | ✅ Full |
| Automation | ❌ Manual console | ✅ Fully automated |
| Template Creation | ❌ Clone only | ✅ Customized install |
| Network Pre-config | ❌ No | ✅ Yes |
| Flexibility | ⚠️ Limited | ✅ High |

## Investigation Needed

Before implementing, we need to understand:

1. **Boot Menu Structure**
   - What does the USB ISO boot menu look like?
   - What are the boot options?
   - Are there kernel parameters we can pass?

2. **Installation Process**
   - Is it an automated installer or manual?
   - Does it auto-login after installation?
   - What prompts appear during boot?

3. **Network Configuration Timing**
   - Can we configure network during installation?
   - Or do we configure after first boot?

## Quick Test

Let's test the ISO boot process:

```bash
# Create a test VM with ISO
govc vm.create -on=false \
  -c=2 -m=4096 \
  -disk=50GB \
  -net="VM Network" \
  -iso="[datastore1] iso/clevos-3.20.1.59-manager-usbiso.iso" \
  test-cos-manager

# Power on and watch boot process
govc vm.power -on test-cos-manager

# Open console to see boot menu
# In vCenter UI: VM → Launch Web Console
# Document what you see!
```

## Next Steps

1. **Test ISO Boot** - Boot a VM from ISO and document the process
2. **Identify Boot Commands** - Determine exact keystrokes needed
3. **Create Packer Templates** - Build automated templates
4. **Update Terraform** - Use templates instead of OVA
5. **Document** - Update README with new workflow

## Comparison: Before vs After

### Before (OVA Files)
```bash
terraform apply          # 5 min - creates VMs
# Manual console config  # 20 min - configure each VM
# Total: 25 minutes
```

### After (USB ISO + Packer)
```bash
# One-time setup
packer build ...         # 30 min - create templates

# Every deployment
terraform apply          # 5 min - fully configured VMs
# Total: 5 minutes (after initial setup)
```

## Conclusion

**The USB ISO files are the solution!** They enable:

✅ **Full automation** with Packer boot commands  
✅ **Template-based deployment** with Terraform  
✅ **No manual console configuration** required  
✅ **Repeatable, scalable deployments**  
✅ **Industry-standard workflow** (Packer + Terraform)

This is the **optimal solution** for VMware vCenter deployment!

## Action Items

1. Upload ISO files to vCenter datastore
2. Test boot process and document boot menu
3. Create Packer templates with boot commands
4. Update Terraform to use templates
5. Enjoy fully automated deployments! 🚀