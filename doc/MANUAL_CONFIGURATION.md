# Manual Configuration Guide for IBM COS VMs

Since the Terraform deployment encountered connectivity issues, you can manually configure the VMs through the vCenter console.

## Manager VM Configuration (10.33.3.200)

The Manager VM is already created and booted. Configure it via vCenter console:

### 1. Login to Manager VM Console
- Username: `root`
- Default Password: `Passw0rd` (or check your OVA documentation)

### 2. Configure Network
```bash
# Set IP address
ip addr add 10.33.3.200/24 dev eth0
ip link set eth0 up

# Set default gateway
ip route add default via 10.33.3.1

# Configure DNS
echo "nameserver 10.33.3.1" > /etc/resolv.conf
echo "nameserver 10.33.3.2" >> /etc/resolv.conf

# Make network configuration persistent
# Edit /etc/sysconfig/network-scripts/ifcfg-eth0 or equivalent
```

### 3. Run Initial Configuration
```bash
# The COS setup wizard should start automatically
# Or run manually:
/opt/ibm/cos/bin/setup-wizard
```

Follow the prompts:
- Hostname: `manager`
- Organization: `IBM`
- Country: `DE`
- Admin username: `localadmin`
- Admin password: `password` (change this!)

## Alternative: Complete Deployment via Terraform

If you want to retry the Terraform deployment:

### Option 1: Refresh and Continue
```bash
cd /Users/olemyk/Documents/github-local/ibm-cos-vm-iac-vcenter

# Check current state
terraform show

# If Manager VM exists in state, try to continue
terraform apply -auto-approve
```

### Option 2: Clean Start
```bash
# Remove the Manager VM from vCenter manually first, then:
terraform destroy -auto-approve
terraform apply -auto-approve
```

### Option 3: Manual Configuration + Terraform Import
```bash
# Configure Manager manually via console (steps above)
# Then deploy remaining VMs:
terraform apply -target=module.cos_accesser -auto-approve
terraform apply -target=module.cos_slicestor[0] -auto-approve
terraform apply -target=module.cos_slicestor[1] -auto-approve
terraform apply -target=module.cos_slicestor[2] -auto-approve
```

## Accesser VM Configuration (10.33.3.201)

Once Accesser VM is created:
1. Login via console (root/Passw0rd)
2. Configure network:
```bash
ip addr add 10.33.3.201/24 dev eth0
ip link set eth0 up
ip route add default via 10.33.3.1
echo "nameserver 10.33.3.1" > /etc/resolv.conf
```
3. Run setup wizard pointing to Manager: `10.33.3.200`

## Slicestor VMs Configuration

For each Slicestor (10.33.3.202, 10.33.3.203, 10.33.3.204):
1. Login via console
2. Configure network with respective IP
3. Run setup wizard pointing to Manager: `10.33.3.200`

## Verification

After all VMs are configured:

1. Access Manager UI: `https://10.33.3.200`
2. Login with localadmin/password
3. Verify all nodes are registered
4. Configure storage pools using the 12 data disks on each Slicestor

## Troubleshooting

### If Terraform state is corrupted:
```bash
# Backup state
cp terraform.tfstate terraform.tfstate.backup

# Remove problematic resource
terraform state rm module.cos_manager.vsphere_virtual_machine.manager

# Re-import if VM exists
terraform import module.cos_manager.vsphere_virtual_machine.manager <vm-id-from-vcenter>
```

### If network configuration doesn't persist:
Check the network configuration files in `/etc/sysconfig/network-scripts/` or `/etc/netplan/` depending on the OS.

### If VMs can't communicate:
- Verify all VMs are on the same network (10.33.3.0/24)
- Check vCenter port group settings
- Verify firewall rules allow traffic between VMs