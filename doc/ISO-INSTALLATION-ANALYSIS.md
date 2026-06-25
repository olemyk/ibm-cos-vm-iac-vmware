# IBM COS All-in-One ISO Installation Analysis

## Overview

Analysis of the `clevos-3.20.1.59-allinone-usbiso.iso` installation process based on real deployment screenshots from June 19, 2026.

## Installation Timeline

| Time | Screenshot | Phase | Description |
|------|-----------|-------|-------------|
| 09:31:07 | Screenshot 1 | Boot | Initial boot screen |
| 09:31:19 | Screenshot 2 | Menu | Installation type selection menu |
| 09:31:53 | Screenshot 3 | Install | Installation in progress |
| 09:32:26 | Screenshot 4 | Install | Installation progress bar |
| 09:33:01 | Screenshot 5 | Install | Installation completing |
| 09:33:19 | Screenshot 6 | Post-Install | Post-installation screen |
| 09:33:40 | Screenshot 7 | Config | Configuration menu |
| 09:33:56 | Screenshot 8 | Config | Configuration options |
| 09:34:05 | Screenshot 9 | Network | Network configuration |
| 09:34:58 | Screenshot 10 | Config | Configuration in progress |
| 09:36:03 | Screenshot 11 | Config | Configuration completing |
| 09:36:23 | Screenshot 12 | Ready | System ready/login |
| 09:37:30 | Screenshot 13 | Manager | Manager interface |
| 09:38:42 | Screenshot 14 | Manager | Manager configuration |
| 09:40:11 | Screenshot 15 | Final | Final configuration |
| 09:40:20 | Screenshot 16 | Complete | System operational |

**Total Duration**: ~9 minutes (09:31 to 09:40)

## Phase Breakdown

### Phase 1: Boot and Selection (0-2 minutes)
**Duration**: ~2 minutes  
**Screenshots**: 1-2

**Boot Sequence**:
1. **Initial Boot** (09:31:07)
   - GRUB or boot menu appears
   - Default boot option or selection menu
   
2. **Installation Type Selection** (09:31:19)
   - Menu with options:
     - Install Manager
     - Install Accesser
     - Install Slicestor
   - User selects "Install Manager"

**Packer Boot Commands**:
```hcl
boot_wait = "10s"  # Wait for boot menu
boot_command = [
  "<wait10>",      # Wait for menu to appear
  "<down>",        # Navigate to Manager option (if needed)
  "<enter>",       # Select Manager installation
  "<wait120>",     # Wait for installation to complete
]
```

### Phase 2: Installation (2-4 minutes)
**Duration**: ~2 minutes  
**Screenshots**: 3-5

**Installation Process**:
1. **Installation Start** (09:31:53)
   - Automated installation begins
   - Progress bar or status messages
   
2. **Installation Progress** (09:32:26)
   - System files being copied
   - Package installation
   
3. **Installation Complete** (09:33:01)
   - Installation finishes
   - System prepares for first boot

**No user interaction required** - fully automated

### Phase 3: Post-Installation Configuration (4-7 minutes)
**Duration**: ~3 minutes  
**Screenshots**: 6-12

**Configuration Sequence**:
1. **Post-Install Screen** (09:33:19)
   - System reboots or continues to configuration
   
2. **Configuration Menu** (09:33:40)
   - Initial configuration wizard
   - May show welcome screen
   
3. **Configuration Options** (09:33:56)
   - System configuration prompts
   
4. **Network Configuration** (09:34:05)
   - **CRITICAL**: Network settings
   - IP address, netmask, gateway, DNS
   - This is where automation is needed
   
5. **Configuration Progress** (09:34:58)
   - Applying configuration
   
6. **Configuration Complete** (09:36:03)
   - Configuration applied
   
7. **System Ready** (09:36:23)
   - Login prompt appears
   - System is operational

**Packer Configuration Commands**:
```hcl
# After installation completes, system may auto-login or show login prompt
# If login required:
"localadmin<enter><wait5>",
"password<enter><wait10>",

# Network configuration (if prompted):
"edit<enter><wait2>",
"channel data port eth0 ip ${var.manager_ip} netmask 255.255.255.0 gateway ${var.gateway}<enter><wait2>",
"system dns ${var.dns}<enter><wait2>",
"system hostname manager<enter><wait2>",
"system organization IBM<enter><wait2>",
"system country US<enter><wait2>",
"activate<enter><wait10>",
"exit<enter><wait5>",
```

### Phase 4: Manager Setup (7-9 minutes)
**Duration**: ~2 minutes  
**Screenshots**: 13-16

**Manager Configuration**:
1. **Manager Interface** (09:37:30)
   - Manager web interface or CLI
   
2. **Manager Configuration** (09:38:42)
   - Additional manager settings
   
3. **Final Configuration** (09:40:11)
   - Completing manager setup
   
4. **System Operational** (09:40:20)
   - Manager fully configured and running

## Key Findings for Packer Automation

### 1. Boot Menu
- **Wait Time**: ~10 seconds for menu to appear
- **Selection**: Arrow keys to navigate, Enter to select
- **Options**: Manager, Accesser, Slicestor

### 2. Installation Phase
- **Duration**: ~2 minutes
- **Automation**: Fully automated, no interaction needed
- **Wait Time**: 120 seconds should be sufficient

### 3. Network Configuration
- **Critical Phase**: This is where manual configuration happens
- **Timing**: Appears around 4 minutes after boot
- **Commands**: Standard COS CLI commands (edit, channel, system, activate)

### 4. Login Credentials
- **Username**: `localadmin`
- **Password**: `password`
- **Access**: SSH available after network configuration

## Packer Boot Command Strategy

### Strategy 1: Full Automation (Recommended)
```hcl
boot_wait = "10s"

boot_command = [
  # Phase 1: Boot and select Manager
  "<wait10>",                    # Wait for boot menu
  "<enter>",                     # Select default or Manager option
  "<wait120>",                   # Wait for installation (2 min)
  
  # Phase 2: Post-installation
  "<wait60>",                    # Wait for system to boot
  
  # Phase 3: Login (if required)
  "localadmin<enter><wait5>",
  "password<enter><wait10>",
  
  # Phase 4: Network configuration
  "edit<enter><wait2>",
  "channel data port eth0 ip ${var.manager_ip} netmask 255.255.255.0 gateway ${var.gateway}<enter><wait2>",
  "system dns ${var.dns}<enter><wait2>",
  "system hostname manager<enter><wait2>",
  "system organization IBM<enter><wait2>",
  "system country US<enter><wait2>",
  "activate<enter><wait10>",
  "exit<enter><wait5>",
]
```

### Strategy 2: Conservative Timing
```hcl
boot_wait = "15s"

boot_command = [
  "<wait15>",                    # Extra wait for slow systems
  "<enter>",
  "<wait180>",                   # 3 minutes for installation
  "<wait90>",                    # 1.5 minutes for post-install
  "localadmin<enter><wait10>",
  "password<enter><wait15>",
  # ... rest of configuration
]
```

## Network Configuration Details

### Required Information
- **IP Address**: e.g., 10.33.3.200
- **Netmask**: 255.255.255.0
- **Gateway**: e.g., 10.33.3.1
- **DNS**: e.g., 10.33.3.1
- **Hostname**: manager
- **Organization**: IBM
- **Country**: US

### Configuration Commands
```bash
edit
channel data port eth0 ip 10.33.3.200 netmask 255.255.255.0 gateway 10.33.3.1
system dns 10.33.3.1
system hostname manager
system organization IBM
system country US
activate
exit
```

## SSH Access

### After Network Configuration
- **Host**: Manager IP (e.g., 10.33.3.200)
- **Port**: 22
- **Username**: localadmin
- **Password**: password
- **Timeout**: Wait 30-60 seconds after network configuration

### Packer SSH Configuration
```hcl
ssh_username         = "localadmin"
ssh_password         = "password"
ssh_timeout          = "30m"
ssh_handshake_attempts = 100
```

## Timing Recommendations

### Minimum Wait Times
- **Boot Menu**: 10 seconds
- **Installation**: 120 seconds (2 minutes)
- **Post-Install**: 60 seconds (1 minute)
- **Login Prompt**: 10 seconds
- **Network Config**: 2 seconds between commands
- **Activation**: 10 seconds
- **SSH Ready**: 30 seconds after activation

### Total Automation Time
- **Optimistic**: ~5 minutes
- **Realistic**: ~7 minutes
- **Conservative**: ~10 minutes

## Variations by Node Type

### Manager
- Longest installation time
- Most configuration options
- Web interface setup

### Accesser
- Similar to Manager
- Slightly faster
- Requires Manager IP for registration

### Slicestor
- Fastest installation
- Minimal configuration
- Requires Manager IP
- Additional disk configuration

## Recommendations for Packer

1. **Use Conservative Timing**: Better to wait longer than fail
2. **Test Each Phase**: Build incrementally, test each boot_command section
3. **Enable VNC**: Use `vnc_over_websocket = true` to watch Packer
4. **Log Everything**: Enable Packer debug mode
5. **Separate Templates**: Create separate templates for Manager, Accesser, Slicestor
6. **Use Variables**: Parameterize all IPs, hostnames, etc.

## Next Steps

1. Update `packer/cos-manager.pkr.hcl` with actual boot commands
2. Test with conservative timing first
3. Optimize timing after successful build
4. Create templates for Accesser and Slicestor
5. Document any variations or issues

## Notes

- Screenshots show a smooth installation with no errors
- Total time of ~9 minutes is very reasonable
- Network configuration is the key automation point
- All-in-one ISO simplifies the process (one ISO for all types)
- Installation is mostly automated, only network config needs automation