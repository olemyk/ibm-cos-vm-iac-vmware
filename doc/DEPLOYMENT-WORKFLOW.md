# IBM COS Deployment Workflow

This document provides a visual overview of the complete deployment process using Packer and Terraform.

## Overview

The deployment uses a **two-phase approach** to enable fully automated, repeatable deployments:

1. **Phase 1 (Packer)**: One-time template creation from ISO (~50 minutes)
2. **Phase 2 (Terraform)**: Repeatable VM deployment from templates (~40-45 minutes)

## Complete Workflow Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    PHASE 1: PACKER TEMPLATE CREATION                    │
│                         (One-Time Setup: ~50 minutes)                   │
└─────────────────────────────────────────────────────────────────────────┘

┌──────────────────┐
│  Prerequisites   │
├──────────────────┤
│ • Packer 1.8+    │
│ • govc CLI       │
│ • SSH client     │
│ • vCenter 7.0+   │
└────────┬─────────┘
         │
         ↓
┌──────────────────────────────────────────────────────────────┐
│ Step 1: Upload ISO to vCenter Datastore                     │
├──────────────────────────────────────────────────────────────┤
│ $ govc datastore.upload \                                    │
│     clevos-3.20.1.59-allinone-usbiso.iso \                  │
│     iso/clevos-3.20.1.59-allinone-usbiso.iso                │
│                                                              │
│ Result: ISO available at [datastore1] iso/clevos-*.iso      │
└────────────────────────────┬─────────────────────────────────┘
                             │
                             ↓
┌──────────────────────────────────────────────────────────────┐
│ Step 2: Generate SSH Key for Automation                     │
├──────────────────────────────────────────────────────────────┤
│ $ cd packer                                                  │
│ $ ./setup-ssh-key.sh                                         │
│                                                              │
│ Result: packer_rsa and packer_rsa.pub created               │
└────────────────────────────┬─────────────────────────────────┘
                             │
                             ↓
┌──────────────────────────────────────────────────────────────┐
│ Step 3: Configure Packer Variables                          │
├──────────────────────────────────────────────────────────────┤
│ $ cp variables.pkrvars.hcl.example variables.pkrvars.hcl    │
│ $ vi variables.pkrvars.hcl                                   │
│                                                              │
│ Configure:                                                   │
│ • vCenter connection (server, credentials)                  │
│ • Template network IPs (10.33.3.200-202)                    │
│ • ISO path in datastore                                     │
└────────────────────────────┬─────────────────────────────────┘
                             │
                             ↓
┌──────────────────────────────────────────────────────────────┐
│ Step 4: Build Templates with Packer                         │
├──────────────────────────────────────────────────────────────┤
│ $ ./build-all-templates.sh                                   │
│                                                              │
│ Builds 3 templates sequentially:                            │
│                                                              │
│ ┌────────────────────────────────────────────┐              │
│ │ Manager Template (~17 min)                 │              │
│ ├────────────────────────────────────────────┤              │
│ │ 1. Create VM from ISO                      │              │
│ │ 2. Boot and send automated commands        │              │
│ │ 3. Configure: IP, SSH, hostname            │              │
│ │ 4. Install SSH public key                  │              │
│ │ 5. Convert to template                     │              │
│ │ Result: cos-manager-template @ 10.33.3.200 │              │
│ └────────────────────────────────────────────┘              │
│                                                              │
│ ┌────────────────────────────────────────────┐              │
│ │ Accesser Template (~17 min)                │              │
│ ├────────────────────────────────────────────┤              │
│ │ 1. Create VM from ISO                      │              │
│ │ 2. Boot and send automated commands        │              │
│ │ 3. Configure: IP, SSH, hostname            │              │
│ │ 4. Install SSH public key                  │              │
│ │ 5. Convert to template                     │              │
│ │ Result: cos-accesser-template @ 10.33.3.201│              │
│ └────────────────────────────────────────────┘              │
│                                                              │
│ ┌────────────────────────────────────────────┐              │
│ │ Slicestor Template (~17 min)               │              │
│ ├────────────────────────────────────────────┤              │
│ │ 1. Create VM from ISO                      │              │
│ │ 2. Boot and send automated commands        │              │
│ │ 3. Configure: IP, SSH, hostname            │              │
│ │ 4. Add 12 × 16GB data disks                │              │
│ │ 5. Install SSH public key                  │              │
│ │ 6. Convert to template                     │              │
│ │ Result: cos-slicestor-template @ 10.33.3.202│             │
│ └────────────────────────────────────────────┘              │
└────────────────────────────┬─────────────────────────────────┘
                             │
                             ↓
┌──────────────────────────────────────────────────────────────┐
│ Step 5: Verify Templates                                    │
├──────────────────────────────────────────────────────────────┤
│ $ govc ls /Datacenter/vm/Templates                           │
│ $ ssh -i packer_rsa localadmin@10.33.3.200 "version"        │
│                                                              │
│ Result: 3 templates ready for Terraform deployment          │
└────────────────────────────┬─────────────────────────────────┘
                             │
                             ↓
                    ┌────────────────┐
                    │ Templates Ready│
                    │ for Terraform  │
                    └────────┬───────┘
                             │
                             ↓

┌─────────────────────────────────────────────────────────────────────────┐
│                   PHASE 2: TERRAFORM DEPLOYMENT                         │
│                    (Repeatable: ~40-45 minutes)                         │
└─────────────────────────────────────────────────────────────────────────┘

┌──────────────────┐
│  Prerequisites   │
├──────────────────┤
│ • Terraform 1.0+ │
│ • Expect         │
│ • SSH client     │
│ • Packer templates│
└────────┬─────────┘
         │
         ↓
┌──────────────────────────────────────────────────────────────┐
│ Step 1: Configure Terraform Variables                       │
├──────────────────────────────────────────────────────────────┤
│ $ cp terraform.tfvars.example terraform.tfvars              │
│ $ vi terraform.tfvars                                        │
│                                                              │
│ Configure:                                                   │
│ • vCenter connection                                        │
│ • Production IPs (10.33.3.110-114)                          │
│ • Number of Slicestors (3 or 6)                             │
│ • NTP servers                                               │
│ • Template names                                            │
└────────────────────────────┬─────────────────────────────────┘
                             │
                             ↓
┌──────────────────────────────────────────────────────────────┐
│ Step 2: Initialize Terraform                                │
├──────────────────────────────────────────────────────────────┤
│ $ terraform init                                             │
│                                                              │
│ Result: Providers downloaded, modules initialized           │
└────────────────────────────┬─────────────────────────────────┘
                             │
                             ↓
┌──────────────────────────────────────────────────────────────┐
│ Step 3: Review Deployment Plan                              │
├──────────────────────────────────────────────────────────────┤
│ $ terraform plan                                             │
│                                                              │
│ Review:                                                      │
│ • 1 VM folder                                               │
│ • 1 Manager VM (4 CPU, 16GB, 128GB)                         │
│ • 1 Accesser VM (4 CPU, 16GB, 128GB)                        │
│ • 3 Slicestor VMs (2 CPU, 8GB, 128GB + 12×16GB)            │
└────────────────────────────┬─────────────────────────────────┘
                             │
                             ↓
┌──────────────────────────────────────────────────────────────┐
│ Step 4: Deploy Infrastructure (Sequential)                  │
├──────────────────────────────────────────────────────────────┤
│ $ terraform apply                                            │
│                                                              │
│ ┌────────────────────────────────────────────┐              │
│ │ 1. Manager Deployment (~8-10 min)          │              │
│ ├────────────────────────────────────────────┤              │
│ │ a. Clone from template (10.33.3.200)       │              │
│ │ b. Power on VM                             │              │
│ │ c. Wait for SSH (template IP)              │              │
│ │ d. Part 1: Generate unique key + change IP │              │
│ │    • system rekey (unique fingerprint)     │              │
│ │    • channel data port eth0 ip 10.33.3.110 │              │
│ │    • activate                              │              │
│ │    • reboot (90 sec wait)                  │              │
│ │ e. Part 2: System configuration (new IP)   │              │
│ │    • system dns 8.8.8.8,8.8.4.4            │              │
│ │    • system ntpservers 162.159.200.1       │              │
│ │    • system hostname manager               │              │
│ │    • activate                              │              │
│ │ Result: Manager @ 10.33.3.110 (unique key) │              │
│ └────────────────────────────────────────────┘              │
│                      ↓ depends_on                           │
│ ┌────────────────────────────────────────────┐              │
│ │ 2. Accesser Deployment (~12 min)           │              │
│ ├────────────────────────────────────────────┤              │
│ │ a. Clone from template (10.33.3.201)       │              │
│ │ b. Power on VM                             │              │
│ │ c. Wait for SSH (template IP)              │              │
│ │ d. Part 1: Generate unique key + change IP │              │
│ │    • system rekey (unique fingerprint)     │              │
│ │    • channel data port eth0 ip 10.33.3.111 │              │
│ │    • activate                              │              │
│ │    • reboot (90 sec wait)                  │              │
│ │ e. Part 2: System config + Manager connect │              │
│ │    • system dns, ntpservers, hostname      │              │
│ │    • manager ip 10.33.3.110                │              │
│ │    • activate                              │              │
│ │ Result: Accesser @ 10.33.3.111 (unique key)│              │
│ └────────────────────────────────────────────┘              │
│                      ↓ depends_on                           │
│ ┌────────────────────────────────────────────┐              │
│ │ 3. Slicestor 1 Deployment (~12 min)        │              │
│ ├────────────────────────────────────────────┤              │
│ │ a. Clone from template (10.33.3.202)       │              │
│ │ b. Power on VM                             │              │
│ │ c. Wait for SSH (template IP)              │              │
│ │ d. Part 1: Generate unique key + change IP │              │
│ │    • system rekey (unique fingerprint)     │              │
│ │    • channel data port eth0 ip 10.33.3.112 │              │
│ │    • activate                              │              │
│ │    • reboot (90 sec wait)                  │              │
│ │ e. Part 2: System config + Manager connect │              │
│ │    • system dns, ntpservers, hostname      │              │
│ │    • manager ip 10.33.3.110                │              │
│ │    • activate                              │              │
│ │ Result: Slicestor1 @ 10.33.3.112 (unique)  │              │
│ └────────────────────────────────────────────┘              │
│                      ↓ depends_on                           │
│ ┌────────────────────────────────────────────┐              │
│ │ 4. Slicestor 2 Deployment (~12 min)        │              │
│ ├────────────────────────────────────────────┤              │
│ │ Same process as Slicestor 1                │              │
│ │ Result: Slicestor2 @ 10.33.3.113 (unique)  │              │
│ └────────────────────────────────────────────┘              │
│                      ↓ depends_on                           │
│ ┌────────────────────────────────────────────┐              │
│ │ 5. Slicestor 3 Deployment (~12 min)        │              │
│ ├────────────────────────────────────────────┤              │
│ │ Same process as Slicestor 1                │              │
│ │ Result: Slicestor3 @ 10.33.3.114 (unique)  │              │
│ └────────────────────────────────────────────┘              │
│                                                              │
│ Total Time: ~40-45 minutes                                  │
└────────────────────────────┬─────────────────────────────────┘
                             │
                             ↓
┌──────────────────────────────────────────────────────────────┐
│ Step 5: Verify Deployment                                   │
├──────────────────────────────────────────────────────────────┤
│ # Check all VMs are accessible                              │
│ $ for ip in 10.33.3.110 10.33.3.111 10.33.3.112 \           │
│     10.33.3.113 10.33.3.114; do                             │
│   ssh -i ./packer/packer_rsa localadmin@$ip "version"       │
│ done                                                         │
│                                                              │
│ # Verify unique fingerprints                                │
│ $ for ip in 10.33.3.110 10.33.3.111 10.33.3.112 \           │
│     10.33.3.113 10.33.3.114; do                             │
│   echo "=== $ip ==="                                        │
│   ssh -i ./packer/packer_rsa localadmin@$ip \               │
│     "system fingerprint"                                    │
│ done                                                         │
│                                                              │
│ Result: All VMs running with unique device fingerprints     │
└────────────────────────────┬─────────────────────────────────┘
                             │
                             ↓
┌──────────────────────────────────────────────────────────────┐
│ Step 6: Access Manager UI & Approve Devices                 │
├──────────────────────────────────────────────────────────────┤
│ 1. Open browser: https://10.33.3.110                        │
│ 2. Login: localadmin / password                             │
│ 3. Navigate to: Devices → Pending Approval                  │
│ 4. Approve all 4 devices:                                   │
│    • accesser1 (10.33.3.111)                                │
│    • slicestor1 (10.33.3.112)                               │
│    • slicestor2 (10.33.3.113)                               │
│    • slicestor3 (10.33.3.114)                               │
│                                                              │
│ Result: All devices approved and ready for use              │
└────────────────────────────┬─────────────────────────────────┘
                             │
                             ↓
┌──────────────────────────────────────────────────────────────┐
│ Step 7: Create Storage Pool                                 │
├──────────────────────────────────────────────────────────────┤
│ 1. In Manager UI: Storage → Storage Pools                   │
│ 2. Create new pool:                                         │
│    • Name: pool1                                            │
│    • Width: 3 (requires 12 disks per Slicestor)            │
│    • Select all 3 Slicestors                                │
│    • Select all 12 disks per Slicestor                      │
│                                                              │
│ Result: Storage pool created with 576GB capacity            │
│         (3 Slicestors × 12 disks × 16GB)                    │
└────────────────────────────┬─────────────────────────────────┘
                             │
                             ↓
                    ┌────────────────┐
                    │ Deployment     │
                    │ Complete! 🎉   │
                    └────────────────┘
```

## Key Features

### Unique Device Fingerprints
Each VM gets a unique private key via `system rekey` command:
- Prevents duplicate device issues
- Enables proper Manager registration
- Required for multi-VM deployments from same template

### Sequential Deployment
VMs are deployed one at a time with `depends_on`:
- Prevents IP conflicts during reconfiguration
- Ensures stable network state
- Allows proper ARP propagation (90-second wait)

### Two-Phase Configuration
Each VM goes through two configuration phases:

**Phase 1 (Template IP):**
- Generate unique key (`system rekey`)
- Change IP address
- Activate and reboot

**Phase 2 (Production IP):**
- Configure DNS, NTP, hostname
- Connect to Manager (Accesser/Slicestor only)
- Activate final configuration

### NTP Synchronization
All nodes configured with NTP servers:
- Ensures time synchronization across cluster
- Required for proper COS operation
- Configured automatically during deployment

## Time Breakdown

### Packer Phase (One-Time)
| Task | Duration | Notes |
|------|----------|-------|
| Manager Template | ~17 min | ISO boot + config + template |
| Accesser Template | ~17 min | ISO boot + config + template |
| Slicestor Template | ~17 min | ISO boot + config + 12 disks + template |
| **Total** | **~50 min** | One-time setup |

### Terraform Phase (Repeatable)
| Task | Duration | Notes |
|------|----------|-------|
| Manager Deploy | ~8-10 min | Clone + rekey + IP change + config |
| Accesser Deploy | ~12 min | Clone + rekey + IP change + Manager connect |
| Slicestor 1 Deploy | ~12 min | Clone + rekey + IP change + Manager connect |
| Slicestor 2 Deploy | ~12 min | Clone + rekey + IP change + Manager connect |
| Slicestor 3 Deploy | ~12 min | Clone + rekey + IP change + Manager connect |
| **Total** | **~40-45 min** | Per deployment |

## Network Flow

### Template Network (Packer)
```
10.33.3.200 ─── Manager Template
10.33.3.201 ─── Accesser Template
10.33.3.202 ─── Slicestor Template
```

### Production Network (Terraform)
```
10.33.3.110 ─── Manager ────┐
10.33.3.111 ─── Accesser ───┤
10.33.3.112 ─── Slicestor1 ─┼─── All connect to Manager
10.33.3.113 ─── Slicestor2 ─┤
10.33.3.114 ─── Slicestor3 ─┘
```

## Storage Configuration

### Per Slicestor
- **Boot Disk**: 128 GB (OS and system)
- **Data Disks**: 12 × 16 GB (thick provisioned)
- **Total**: 320 GB per Slicestor

### Total Capacity
- **3 Slicestors**: 576 GB raw data storage
- **6 Slicestors**: 1,152 GB raw data storage

**Note**: 12 disks per Slicestor meets IBM COS minimum requirement for storage pool width 3.

## Advantages

### vs Manual Configuration
| Aspect | Manual | Automated |
|--------|--------|-----------|
| Initial Setup | 0 min | 50 min (one-time) |
| Per Deployment | 60+ min | 40-45 min |
| Human Errors | High risk | Zero risk |
| Consistency | Variable | 100% consistent |
| Scalability | Poor | Excellent |

### vs OVA Deployment
| Aspect | OVA | ISO + Packer |
|--------|-----|--------------|
| Automation | Partial | Full |
| Unique Keys | Manual | Automatic |
| Network Config | Manual | Automatic |
| Template Creation | Clone only | Custom install |
| Flexibility | Limited | High |

## Troubleshooting

### Packer Phase Issues
- **ISO not found**: Verify upload with `govc datastore.ls iso/`
- **SSH timeout**: Check template IP is accessible
- **Boot commands fail**: Review VM console during build

### Terraform Phase Issues
- **Template not found**: Run `govc ls /Datacenter/vm/Templates`
- **IP conflict**: Ensure template and production IPs don't overlap
- **SSH fails**: Verify packer_rsa key exists and has correct permissions
- **Duplicate fingerprints**: Check `system rekey` executed successfully

## Best Practices

1. **Keep templates updated**: Rebuild when new COS version available
2. **Use separate IP ranges**: Template IPs vs production IPs
3. **Monitor deployment logs**: Check for errors during apply
4. **Verify fingerprints**: Ensure all devices have unique keys
5. **Sequential deployment**: Don't modify depends_on relationships
6. **Backup state files**: Terraform state contains important data

## Next Steps

After successful deployment:

1. **Complete first-time setup** in Manager UI
2. **Approve all devices** (Accesser + Slicestors)
3. **Create storage pool** with width 3
4. **Configure vaults** for object storage
5. **Set up S3 access** through Accesser
6. **Test object operations** (PUT/GET/DELETE)

## References

- [IBM COS Documentation](https://www.ibm.com/docs/en/coss)
- [Packer vSphere ISO Builder](https://www.packer.io/plugins/builders/vsphere/vsphere-iso)
- [Terraform vSphere Provider](https://registry.terraform.io/providers/hashicorp/vsphere/latest/docs)
- [Project README](README.md)
- [Packer README](packer/README.md)