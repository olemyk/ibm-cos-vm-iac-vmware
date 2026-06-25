# System Rekey Fix for Cloned VMs

## Critical Issue Discovered

When VMs are cloned from Packer templates, they inherit the **same private key and fingerprint** from the template. This prevents proper device registration with the IBM COS Manager because the Manager identifies devices by their unique private key fingerprint.

## Symptoms

- Multiple devices showing the same fingerprint when running `system fingerprint`
- Only one device (usually the last deployed) appearing in Manager's "Devices Pending Approval"
- Other devices not registering with Manager despite having correct Manager IP configured

## Root Cause

```bash
# All cloned VMs had identical fingerprints:
slicestor1# system fingerprint
75:0e:50:7c:57:f7:f5:70:8f:89:ed:53:90:e4:33:78:7c:ac:9a:8d

slicestor2# system fingerprint
75:0e:50:7c:57:f7:f5:70:8f:89:ed:53:90:e4:33:78:7c:ac:9a:8d  # SAME!

slicestor3# system fingerprint
75:0e:50:7c:57:f7:f5:70:8f:89:ed:53:90:e4:33:78:7c:ac:9a:8d  # SAME!
```

## Solution: `system rekey` Command

The `system rekey` command generates a new unique private key for each device:

```bash
slicestor2 (working)# system rekey
WARNING: Resetting the private key will require that this
device be re-registered with the manager before it will
function properly.

Reset private key? [y/N]: y
Private key reset.  Please activate and then re-approve this
device in the manager interface.

slicestor2 (working)# activate
Please wait, this may take several minutes....
check OK
activate OK
```

## Implementation

Added `system rekey` to all three configuration scripts:

### 1. configure-manager.expect
```tcl
# Generate unique private key for this VM (critical for cloned VMs)
send "system rekey\r"
expect {
    "Reset private key?" {
        send "y\r"
        expect {
            "Private key reset" {
                puts "Private key regenerated successfully"
            }
            timeout {
                puts "Timeout waiting for rekey confirmation"
                exit 1
            }
        }
        expect -re "#|>"
    }
    -re "#|>" {
        puts "No rekey prompt (unexpected)"
    }
    timeout {
        puts "Timeout waiting for rekey prompt"
        exit 1
    }
}
```

### 2. configure-accesser.expect
Same `system rekey` block added before `manager ip` command.

### 3. configure-slicestor.expect
Same `system rekey` block added before `manager ip` command.

## Configuration Sequence

The updated configuration sequence for each device:

1. **Part 1: IP Change**
   - Connect to template IP (10.33.3.200-202)
   - Change IP to production IP
   - Activate (connection lost)
   - Wait 90 seconds for ARP propagation

2. **Part 2: System Configuration**
   - Reconnect to new IP
   - Configure DNS, hostname, organization, country
   - **Run `system rekey`** ← NEW STEP
   - Configure Manager IP (for Accesser/Slicestor)
   - Activate
   - Exit

## Why This Matters

1. **Device Identity**: Each device must have a unique private key to be identified by the Manager
2. **Security**: Prevents multiple devices from impersonating each other
3. **Registration**: Manager uses the fingerprint to track device registration requests
4. **Approval**: Each device appears separately in the "Devices Pending Approval" list

## Verification

After deployment, verify each device has a unique fingerprint:

```bash
cd ../ibm-cos-vm-iac-vcenter

# Check Manager
ssh -i ./packer/packer_rsa localadmin@10.33.3.110 "system fingerprint"

# Check Accesser
ssh -i ./packer/packer_rsa localadmin@10.33.3.111 "system fingerprint"

# Check Slicestors
for ip in 10.33.3.112 10.33.3.113 10.33.3.114; do
  echo "=== Checking $ip ==="
  ssh -i ./packer/packer_rsa localadmin@$ip "system fingerprint"
done
```

**Expected**: Each device should show a **different** fingerprint.

## Impact on Deployment

- **Deployment Time**: Adds ~5-10 seconds per device for key regeneration
- **Total Impact**: Minimal (~30 seconds for full deployment)
- **Reliability**: Critical for proper device registration

## Testing Results

After implementing `system rekey`:
- ✅ All devices appeared in "Devices Pending Approval"
- ✅ Each device had unique fingerprint
- ✅ Manager could identify and track each device separately
- ✅ Device approval process worked correctly

## Alternative Approaches Considered

1. **Generate keys in Packer template**: Not feasible - template is built once, all clones would still share the key
2. **Post-clone script**: Would require additional orchestration outside Terraform
3. **Manual rekey**: Not scalable, defeats automation purpose

**Conclusion**: Adding `system rekey` to the configuration scripts is the most elegant and automated solution.

## References

- IBM COS CLI Command: `system rekey`
- IBM COS CLI Help: `system help`
- Device Registration: Requires unique private key fingerprint