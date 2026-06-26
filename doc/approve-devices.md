# Approving Devices in IBM COS Manager

## Issue

After deployment, Slicestor and Accesser nodes register with the Manager but require manual approval before they can join the cluster. This is a security feature of IBM COS.

## Current Status

From your screenshot, the following devices are pending approval:
- **accesser1** (10.33.3.111) - Registered: 2026-06-23 08:11:45 GMT
- **slicestor3** (10.33.3.114) - Registered: 2026-06-23 08:57:41 GMT

**Missing from pending list**:
- slicestor1 (10.33.3.112)
- slicestor2 (10.33.3.113)

## Why Slicestor 1 & 2 Are Not Showing

All three Slicestors have the Manager IP configured correctly (verified via CLI):

```bash
# All three show: Manager IP: 10.33.3.110
slicestor1# manager
slicestor2# manager  
slicestor3# manager
```

**Possible reasons**:
1. **Timing**: They may have registered but were already approved/processed
2. **Network delay**: Registration packets may have been delayed
3. **Manager restart**: If Manager was restarted, pending approvals may have been cleared
4. **Already approved**: They may have been auto-approved or manually approved earlier

## Solution: Approve Devices via Web UI

### Step 1: Access Manager Web Interface

```bash
# Open in browser
https://10.33.3.110
```

**Login credentials**: Use the credentials set during Manager installation

### Step 2: Navigate to Device Approval

1. Log in to Manager web interface
2. Go to **System** → **Devices** or **Device Management**
3. Look for **Pending Approvals** section

### Step 3: Approve Devices

For each pending device:
1. Select the device (checkbox)
2. Click **Approve** or **Bulk Approve** button
3. Confirm the approval

### Step 4: Verify Approved Devices

After approval, devices should appear in:
- **System** → **Devices** → **Active Devices**
- Status should change from "Pending" to "Active" or "Online"

## Alternative: Check Device Status via CLI

### Check if Slicestors are actually registered

```bash
cd ../ibm-cos-vm-iac-vcenter

# Create verification script
cat > check-device-status.expect << 'EOF'
#!/usr/bin/expect -f
set timeout 10

puts "\n=== Checking Manager for registered devices ==="

spawn ssh -i ./packer/packer_rsa -o StrictHostKeyChecking=no localadmin@10.33.3.110

expect {
    -re "#|>" {
        send "device list\r"
        expect -re "#|>"
        puts $expect_out(buffer)
        send "exit\r"
        expect eof
    }
    timeout {
        puts "Connection timeout"
    }
}
EOF

chmod +x check-device-status.expect
./check-device-status.expect
```

## Manual Re-registration (if needed)

If Slicestor 1 & 2 are not showing up at all, you can manually trigger re-registration:

```bash
# For each Slicestor that's not showing
for ip in 10.33.3.112 10.33.3.113; do
  echo "Re-registering Slicestor at $ip"
  ssh -i ./packer/packer_rsa -o StrictHostKeyChecking=no localadmin@$ip << 'EOSSH'
edit
manager ip 10.33.3.110
activate
exit
EOSSH
done
```

## Expected Result After Approval

Once all devices are approved:
- **1 Manager**: 10.33.3.110
- **1 Accesser**: 10.33.3.111
- **3 Slicestors**: 10.33.3.112-114

All devices should show as "Active" or "Online" in the Manager web interface.

## Next Steps After Approval

1. **Create Storage Pool**: Configure Slicestor nodes into a storage pool
2. **Create Vault**: Create a vault for object storage
3. **Configure S3 Access**: Set up S3 API access through Accesser
4. **Test Object Storage**: Upload/download test objects

## Troubleshooting

### Device Not Appearing in Pending List

1. **Check Manager IP on device**:
   ```bash
   ssh -i ./packer/packer_rsa localadmin@<device-ip>
   # In COS shell:
   manager
   ```

2. **Check network connectivity**:
   ```bash
   ping 10.33.3.110  # From your workstation
   ssh -i ./packer/packer_rsa localadmin@<device-ip> "ping -c 3 10.33.3.110"
   ```

3. **Check Manager logs** (via web UI):
   - System → Logs
   - Look for device registration attempts

### Device Stuck in Pending

1. **Restart device**:
   ```bash
   ssh -i ./packer/packer_rsa localadmin@<device-ip>
   # In COS shell:
   reboot
   ```

2. **Check certificate** (should have been accepted during configuration):
   ```bash
   ssh -i ./packer/packer_rsa localadmin@<device-ip>
   # In COS shell:
   manager
   # Should show certificate details
   ```

## Automation Note

Device approval is intentionally manual for security reasons. IBM COS does not provide an API for automatic approval to prevent unauthorized devices from joining the cluster.