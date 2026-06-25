# Packer template for IBM COS Accesser VM from All-in-One ISO
# Based on successful Manager template
#
# Prerequisites:
# 1. Upload clevos-3.20.1.59-allinone-usbiso.iso to vCenter datastore
# 2. Install Packer: https://www.packer.io/downloads
# 3. Ensure packer_rsa SSH key exists in this directory
#
# Usage:
#   packer build -var-file=variables.pkrvars.hcl cos-accesser.pkr.hcl

packer {
  required_version = ">= 1.8.0"
  
  required_plugins {
    vsphere = {
      version = ">= 1.2.0"
      source  = "github.com/hashicorp/vsphere"
    }
  }
}

# Variables
variable "vcenter_server" {
  type        = string
  description = "vCenter server FQDN or IP"
}

variable "vcenter_username" {
  type        = string
  description = "vCenter username"
}

variable "vcenter_password" {
  type        = string
  sensitive   = true
  description = "vCenter password"
}

variable "vcenter_datacenter" {
  type        = string
  description = "vCenter datacenter name"
}

variable "vcenter_cluster" {
  type        = string
  description = "vCenter cluster name"
}

variable "vcenter_datastore" {
  type        = string
  description = "vCenter datastore name"
}

variable "vcenter_network" {
  type        = string
  description = "vCenter network name"
}

variable "vcenter_host" {
  type        = string
  default     = ""
  description = "Specific ESXi host to deploy to (optional)"
}

variable "vcenter_folder" {
  type        = string
  default     = "Templates"
  description = "vCenter folder for templates"
}

variable "accesser_ip" {
  type        = string
  default     = "10.33.3.201"
  description = "Accesser VM IP address"
}

variable "netmask" {
  type        = string
  default     = "255.255.255.0"
  description = "Network netmask"
}

variable "gateway" {
  type        = string
  description = "Network gateway"
}

variable "dns" {
  type        = string
  description = "DNS server"
}

variable "ntp" {
  type        = string
  default     = ""
  description = "NTP server (optional)"
}

variable "iso_path" {
  type        = string
  default     = "[datastore1] iso/clevos-3.20.1.59-allinone-usbiso.iso"
  description = "Path to All-in-One USB ISO in datastore"
}

variable "organization" {
  type        = string
  default     = "IBM"
  description = "Organization name"
}

variable "country" {
  type        = string
  default     = "US"
  description = "Country code"
}

# Source configuration
source "vsphere-iso" "cos-accesser" {
  # vCenter connection
  vcenter_server      = var.vcenter_server
  username            = var.vcenter_username
  password            = var.vcenter_password
  insecure_connection = true

  # VM location
  datacenter = var.vcenter_datacenter
  cluster    = var.vcenter_cluster
  host       = var.vcenter_host  # Optional: pin to specific ESXi host
  datastore  = var.vcenter_datastore
  folder     = var.vcenter_folder

  # VM configuration
  vm_name              = "cos-accesser-template"
  notes                = "IBM COS Accesser template created by Packer from All-in-One ISO"
  guest_os_type        = "other3xLinux64Guest"
  CPUs                 = 4      # Updated to 4 vCPUs per IBM docs
  RAM                  = 16384  # 16 GB - Updated per IBM docs
  RAM_reserve_all      = false
  firmware             = "bios"
  disk_controller_type = ["pvscsi"]  # Paravirtual SCSI
  
  storage {
    disk_size             = 131072  # 128 GB (unchanged per IBM docs)
    disk_thin_provisioned = false   # Thick Provision Lazy Zeroed
    disk_eagerly_scrub    = false   # Lazy Zeroed (not Eager Zeroed)
  }

  network_adapters {
    network      = var.vcenter_network
    network_card = "vmxnet3"
  }

  # ISO configuration
  iso_paths = [var.iso_path]
  
  # Remove CD-ROM after installation
  remove_cdrom = true

  # Boot configuration
  # Based on successful Manager build: ~17 minutes total
  # Phase 1: Boot menu (0-2 min)
  # Phase 2: Installation (2-5 min)
  # Phase 3: Configuration (5-8 min)
  # Phase 4: Accesser setup (8-17 min)
  
  boot_wait = "2m"  # Wait 2 minutes for boot menu to appear
  
  boot_command = [
    # ============================================================
    # Phase 1: Boot and Select Accesser Installation (0-2 minutes)
    # ============================================================
    "<wait120>",                    # Wait for boot menu to appear
    "1<enter>",                    # Select option 1: Perform automatic installation
    "<wait5>",                     # Wait for disk erase prompt
    "2<enter>",                    # Select option 2: Erase all disks
    "<wait5>",                     # Wait for confirmation prompt
    "erase<enter>",                # Type "erase" to confirm disk erasure
    "<wait5>",                     # Wait for component selection prompt
    "1<enter>",                    # Select option 1: Accesser component
    "<wait180>",                   # Wait 3 minutes for installation to complete
    
    # ============================================================
    # Phase 2: Post-Installation Boot (2-4 minutes)
    # ============================================================
    "<wait90>",                    # Wait 1.5 minutes for system to boot
    
    # ============================================================
    # Phase 3: Login and Network Configuration (4-7 minutes)
    # ============================================================
    # Login prompt should appear
    "localadmin<enter><wait10>",   # Username
    "password<enter><wait15>",     # Password
    
    # Enter configuration mode
    "edit<enter><wait5>",
    
    # Configure network
    "channel data port eth0 ip ${var.accesser_ip} netmask ${var.netmask} gateway ${var.gateway}<enter><wait5>",
    
    # Configure DNS
    "system dns ${var.dns}<enter><wait5>",
    
    # Configure hostname
    "system hostname accesser<enter><wait5>",
    
    # Configure organization
    "system organization ${var.organization}<enter><wait5>",
    
    # Configure country
    "system country ${var.country}<enter><wait5>",
    
    # ============================================================
    # Phase 4: Configure SSH Key Authentication
    # ============================================================
    
    # Add SSH key (Packer-specific key) - must be quoted
    "sshkeys set -- \"ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDeAkZlikRo3eSFEUqZQP5yPjGLi1yOqAbiJGRLHwXHkCEidU+/RiDU5ByvIMnLkZG/K7DTSUJFNlp685WvbjBqz4cRCGERw7Qji0b5glObI+f9antsQLLCrcHQ5HHcAAzQ3U0ESlY1Z2uqgUizNIMptHBiWtygQOECdMhZprjLoKYoahlcZE8njV8BUQ0iFk4ij6H/u0YkKi5WiZSZmQe9w+SuOdx7VBk2q9w5MOLHqifHzsVlDwDdo+Vx++vuTWkGMS9lmYXlz+djMog0x5u2rLK/IJAipDsYcRd/fy+a8n1mEpzU322JFNLd5J03UvshVreOnfTX1pWfaeul8t2H/g9/Tu599oL7p163yegJ0ZYWGXZP4xbeDVmUbL73zzOL4VOaXeL8GlI47ckHQsyTiLaaXzCkCgOXCz8crU/GAcmWe9KA2TuIeUVQbUKNhZorLVANKiwIRh1mkzuPYV8j9hlqwnjVcz0LAo62ZECwagmtYa3PK3kiwOXSvF3HK3048FWlx2Ww9YADyd/QzuJvJdBlIH/z+QRelxMgbK2G78YPnoJ+DvO/NYNiK257UrfNMWfasFiwQu3jhW0WXSzcm1bWiOeKY717AYanoDtBR2I8fAy9J3LcblqA9BM+ZSPxSWdqhWG0qKvBUFlcHOvBNPGsM1Hvd/iIlnZI1TtbbQ== packer@ibm-cos-automation\"<enter><wait10>",
    
    # Activate SSH key configuration and exit edit mode
    "activate<enter><wait200>",     # Wait for activation to complete (exits edit mode)
    
    # Ping the gateway to verify network connectivity
    "ping -c 4 ${var.gateway}<enter><wait5>",
    
    # ============================================================
    # Phase 5: Wait for SSH to be ready
    # ============================================================
    "<wait30>",                    # Additional wait for SSH service
  ]

  # SSH configuration for post-installation provisioning
  # Use Packer-specific SSH key
  ssh_username               = "localadmin"
  ssh_private_key_file       = "${path.root}/packer_rsa"
  ssh_timeout                = "30m"
  ssh_handshake_attempts     = 100
  ssh_clear_authorized_keys  = false

  # Shutdown configuration - use COS appliance command
  shutdown_command = "poweroff"
  shutdown_timeout = "15m"

  # Convert to template
  convert_to_template = true
  
  # Enable VNC for debugging (optional)
  # vnc_over_websocket = true
}

# Build
build {
  sources = ["source.vsphere-iso.cos-accesser"]
  
  # Post-processor to create template
  post-processor "manifest" {
    output     = "manifest-accesser.json"
    strip_path = true
  }
}