# Automation Options for IBM COS VM Configuration

## The Challenge

IBM COS VMs boot from OVA without network configuration. We need to configure the network before SSH is available. VMware vCenter doesn't provide CLI console access like KVM's `virsh console`.

## Option 1: Current Approach (Manual Console) ⭐ Recommended

**Status**: Implemented in this project

**How it works**:
1. Terraform deploys VMs from OVA
2. User manually configures each VM via vCenter Web Console
3. Once network is configured, SSH is available

**Pros**:
- ✅ Simple and reliable
- ✅ No additional tools required
- ✅ Works with existing OVA files
- ✅ Secure (no ESXi SSH access needed)

**Cons**:
- ❌ Requires manual intervention (~5 min per VM)
- ❌ Not fully automated

**Best for**: Small deployments (3-6 VMs), one-time setups

---

## Option 2: VNC Automation with Packer-like Boot Commands

**Status**: Possible but complex

**How it works**:
1. Deploy VM from OVA with Terraform
2. Enable VNC on the VM
3. Use VNC automation tools to send keystrokes
4. Configure network via VNC

**Tools**:
- `xdotool` - Send keystrokes to VNC session
- `vncdo` - VNC automation tool
- Python `pyvnc` - VNC client library

**Example approach**:
```bash
# 1. Deploy VM with VNC enabled
terraform apply

# 2. Get VNC port from vCenter
govc vm.info -json COS1-Manager | jq '.VirtualMachines[0].Config.ExtraConfig'

# 3. Connect and send keystrokes via VNC
vncdo -s localhost:5900 type "localadmin"
vncdo -s localhost:5900 key enter
vncdo -s localhost:5900 type "password"
vncdo -s localhost:5900 key enter
vncdo -s localhost:5900 type "edit"
vncdo -s localhost:5900 key enter
# ... more commands
```

**Pros**:
- ✅ Can be fully automated
- ✅ Works with existing OVA files
- ✅ No ESXi SSH access needed

**Cons**:
- ❌ Complex setup
- ❌ VNC must be enabled on VMs
- ❌ Timing issues (need to wait for prompts)
- ❌ Fragile (screen changes break automation)
- ❌ Security concerns (VNC traffic)

**Best for**: Large-scale deployments where manual config is impractical

---

## Option 3: ESXi Host SSH with vim-cmd

**Status**: Possible but requires ESXi access

**How it works**:
1. Deploy VM from OVA with Terraform
2. SSH to ESXi host
3. Use `vim-cmd` to send keystrokes to VM console
4. Configure network via console

**Example**:
```bash
# SSH to ESXi host
ssh root@esxi-host.example.com

# Find VM ID
vim-cmd vmsvc/getallvms | grep COS1-Manager

# Send keystrokes to VM console (complex)
# This requires using vim-cmd with special escape sequences
```

**Pros**:
- ✅ Direct console access
- ✅ Works with existing OVA files

**Cons**:
- ❌ Requires ESXi SSH access (security risk)
- ❌ Complex vim-cmd syntax
- ❌ Not portable across ESXi versions
- ❌ Requires root access to ESXi

**Best for**: Environments where ESXi SSH is already enabled

---

## Option 4: PowerCLI with Invoke-VMScript (Requires VMware Tools)

**Status**: Not applicable - VMware Tools not running without network

**How it works**:
- Use PowerCLI's `Invoke-VMScript` to run commands in VM
- Requires VMware Tools to be running

**Why it doesn't work**:
```powershell
Invoke-VMScript -VM "COS1-Manager" -ScriptText "config_net" -GuestUser localadmin -GuestPassword password
# ERROR: VMware Tools is not running
```

VMware Tools needs network connectivity to communicate with vCenter, creating a chicken-and-egg problem.

---

## Option 5: Custom OVA with OVF Properties

**Status**: Would require rebuilding OVA files

**How it works**:
1. Modify IBM COS OVA to support OVF properties
2. Pass network configuration as OVF properties
3. VM reads properties on first boot and configures network

**Example Terraform**:
```hcl
resource "vsphere_virtual_machine" "manager" {
  ovf_deploy {
    local_ovf_path = "./ova/clevos-3.20.1.59-manager.ova"
  }
  
  vapp {
    properties = {
      "guestinfo.ipaddress" = "10.33.3.200"
      "guestinfo.netmask"   = "255.255.255.0"
      "guestinfo.gateway"   = "10.33.3.1"
      "guestinfo.dns"       = "10.33.3.1"
    }
  }
}
```

**Pros**:
- ✅ Fully automated
- ✅ Clean and reliable
- ✅ Industry standard approach

**Cons**:
- ❌ Requires modifying IBM COS OVA files
- ❌ Need access to IBM COS source/build process
- ❌ Not possible with pre-built OVA files

**Best for**: If you have access to rebuild the OVA files

---

## Option 6: Cloud-Init / Ignition

**Status**: Not supported by IBM COS

**How it works**:
- Use cloud-init to configure VMs on first boot
- Pass configuration via ISO or network

**Why it doesn't work**:
- IBM COS VMs don't support cloud-init
- Would require rebuilding the OS image

---

## Option 7: Packer to Rebuild OVA with Pre-Configuration

**Status**: Possible but requires significant effort

**How it works**:
1. Use Packer to boot IBM COS OVA
2. Configure network during Packer build
3. Export new OVA with network pre-configured
4. Deploy pre-configured OVA with Terraform

**Packer template example**:
```hcl
source "vsphere-iso" "cos-manager" {
  # Start from IBM COS OVA
  vm_name = "cos-manager-template"
  
  # Boot commands to configure network
  boot_command = [
    "<enter><wait>",
    "localadmin<enter><wait>",
    "password<enter><wait>",
    "edit<enter><wait>",
    "channel data port eth0 ip 10.33.3.200 netmask 255.255.255.0 gateway 10.33.3.1<enter><wait>",
    # ... more commands
  ]
}
```

**Pros**:
- ✅ Creates pre-configured OVA
- ✅ Terraform deployment becomes fully automated
- ✅ Repeatable builds

**Cons**:
- ❌ Complex Packer setup
- ❌ Need to rebuild OVA for each network configuration
- ❌ Not flexible for different environments
- ❌ Packer boot_command works with ISO, not OVA deployment

**Best for**: Creating standardized templates for specific environments

---

## Option 8: Ansible with VMware Guest Operations

**Status**: Same limitation as PowerCLI

**How it works**:
```yaml
- name: Configure COS VM
  vmware_vm_shell:
    hostname: vcenter.example.com
    username: administrator@vsphere.local
    password: password
    vm_id: COS1-Manager
    vm_username: localadmin
    vm_password: password
    vm_shell: /bin/bash
    vm_shell_args: "-c 'config_net'"
```

**Why it doesn't work**:
- Requires VMware Tools to be running
- VMware Tools needs network connectivity

---

## Recommended Solution: Hybrid Approach

For the best balance of automation and practicality:

### Phase 1: Initial Deployment (Manual - One Time)
```bash
# 1. Deploy VMs with Terraform
terraform apply

# 2. Configure network via console (manual, ~20 minutes total)
# Follow MANUAL_CONFIGURATION.md

# 3. Verify SSH access
ssh localadmin@10.33.3.200
```

### Phase 2: Configuration Management (Automated)
```bash
# Once SSH is available, use Ansible/scripts for everything else
ansible-playbook -i inventory.ini configure-cos-cluster.yml
```

### Phase 3: Future Deployments (Mostly Automated)
```bash
# Option A: Clone configured VMs
terraform apply -var="clone_from_template=true"

# Option B: Use VNC automation for large deployments
./scripts/vnc-configure-all-vms.sh
```

---

## Comparison Matrix

| Option | Automation Level | Complexity | Security | Works with OVA |
|--------|-----------------|------------|----------|----------------|
| Manual Console | ⭐ Low | ⭐⭐⭐ Low | ⭐⭐⭐ High | ✅ Yes |
| VNC Automation | ⭐⭐⭐ High | ⭐⭐ Medium | ⭐⭐ Medium | ✅ Yes |
| ESXi SSH | ⭐⭐⭐ High | ⭐⭐ Medium | ⭐ Low | ✅ Yes |
| PowerCLI | ⭐⭐⭐ High | ⭐⭐⭐ Low | ⭐⭐⭐ High | ❌ No (needs network) |
| OVF Properties | ⭐⭐⭐ High | ⭐⭐⭐ Low | ⭐⭐⭐ High | ❌ No (needs rebuild) |
| Packer Rebuild | ⭐⭐ Medium | ⭐ High | ⭐⭐ Medium | ⚠️ Complex |

---

## Conclusion

For **this project**, the **manual console approach** is recommended because:

1. ✅ **Simple and reliable** - Works every time
2. ✅ **Secure** - No ESXi SSH or VNC exposure
3. ✅ **One-time effort** - Only needed during initial deployment
4. ✅ **Well-documented** - Clear step-by-step guide provided
5. ✅ **Production-ready** - Used by many VMware deployments

For **large-scale deployments** (10+ VMs), consider:
- **VNC automation** for fully automated deployment
- **ESXi SSH** if security policies allow
- **Request IBM** to add OVF property support to COS OVA files

The current implementation provides the best balance for typical deployments while maintaining security and reliability.