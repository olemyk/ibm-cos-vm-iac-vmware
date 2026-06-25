#
# Copyright 2024- IBM Inc. All rights reserved
# SPDX-License-Identifier: Apache2.0
#

# vCenter Connection Variables
variable "vsphere_server" {
  description = "vCenter server FQDN or IP address"
  type        = string
}

variable "vsphere_user" {
  description = "vCenter username"
  type        = string
}

variable "vsphere_password" {
  description = "vCenter password"
  type        = string
  sensitive   = true
}

variable "vsphere_allow_unverified_ssl" {
  description = "Allow unverified SSL certificates"
  type        = bool
  default     = false
}

# vCenter Infrastructure Variables
variable "vsphere_datacenter" {
  description = "vCenter datacenter name"
  type        = string
}

variable "vsphere_cluster" {
  description = "vCenter cluster name"
  type        = string
}

variable "vsphere_datastore" {
  description = "vCenter datastore name for VM storage"
  type        = string
}

variable "vsphere_network" {
  description = "vCenter network/port group name"
  type        = string
}
variable "vsphere_host" {
  description = "ESXi host FQDN or IP to pin VMs to (optional)"
  type        = string
  default     = ""
}


variable "vsphere_resource_pool" {
  description = "vCenter resource pool name (optional, leave empty for cluster root)"
  type        = string
  default     = ""
}

# IBM COS Configuration Variables
variable "cos_version" {
  description = "IBM Cloud Object Storage version"
  type        = string
  default     = "3.17.2.40"
}

variable "system_index" {
  description = "System index for multiple COS deployments (1-99)"
  type        = number
  default     = 1

  validation {
    condition     = var.system_index >= 1 && var.system_index <= 99
    error_message = "System index must be between 1 and 99."
  }
}

variable "num_accessers" {
  description = "Number of Accesser nodes (1-3)"
  type        = number
  default     = 1

  validation {
    condition     = var.num_accessers >= 1 && var.num_accessers <= 3
    error_message = "Number of Accessers must be between 1 and 3."
  }
}

variable "num_slicestors" {
  description = "Number of Slicestor nodes (tested with 3 and 6)"
  type        = number
  default     = 3

  validation {
    condition     = contains([3, 6], var.num_slicestors)
    error_message = "Number of Slicestors must be 3 or 6."
  }
}

# Network Configuration Variables
variable "base_ip" {
  description = "Starting IP address for sequential assignment (Manager, Accesser, Slicestor1, Slicestor2, ...)"
  type        = string
  default     = "10.33.3.203"

  validation {
    condition     = can(regex("^(?:[0-9]{1,3}\\.){3}[0-9]{1,3}$", var.base_ip))
    error_message = "Base IP must be a valid IPv4 address."
  }
}

variable "netmask" {
  description = "Network subnet mask"
  type        = string
  default     = "255.255.255.0"
}

variable "gateway" {
  description = "Network gateway IP address"
  type        = string

  validation {
    condition     = can(regex("^(?:[0-9]{1,3}\\.){3}[0-9]{1,3}$", var.gateway))
    error_message = "Gateway must be a valid IPv4 address."
  }
}

variable "dns_servers" {
  description = "DNS server IP addresses (comma-separated)"
  type        = string
  default     = "9.9.9.9,1.1.1.1"
}

variable "ntp_servers" {
  description = "NTP server addresses (comma-separated)"
  type        = string
  default     = "de.pool.ntp.org,us.pool.ntp.org"
}

# VM Resource Configuration
variable "manager_cpu" {
  description = "Number of vCPUs for Manager VM"
  type        = number
  default     = 4  # Updated per IBM docs
}

variable "manager_memory" {
  description = "Memory in MB for Manager VM"
  type        = number
  default     = 16384  # 16 GB - Updated per IBM docs
}

variable "manager_disk_size" {
  description = "Boot disk size in GB for Manager VM"
  type        = number
  default     = 256  # Updated per IBM docs
}

variable "accesser_cpu" {
  description = "Number of vCPUs for Accesser VM"
  type        = number
  default     = 4  # Updated per IBM docs
}

variable "accesser_memory" {
  description = "Memory in MB for Accesser VM"
  type        = number
  default     = 16384  # 16 GB - Updated per IBM docs
}

variable "accesser_disk_size" {
  description = "Boot disk size in GB for Accesser VM"
  type        = number
  default     = 128  # Per IBM docs
}

variable "slicestor_cpu" {
  description = "Number of vCPUs for each Slicestor VM"
  type        = number
  default     = 2  # Updated per IBM docs
}

variable "slicestor_memory" {
  description = "Memory in MB for each Slicestor VM"
  type        = number
  default     = 8192  # 8 GB - Updated per IBM docs
}

variable "slicestor_disk_size" {
  description = "Boot disk size in GB for Slicestor VM"
  type        = number
  default     = 128  # Per IBM docs
}

variable "slicestor_data_disk_size" {
  description = "Size in GB for each Slicestor data disk"
  type        = number
  default     = 128  # Updated from 2 GB to 128 GB
}

variable "slicestor_data_disk_count" {
  description = "Number of data disks per Slicestor (default 12)"
  type        = number
  default     = 12
}

# Packer Template Configuration
variable "cos_manager_template" {
  description = "Name of Manager VM template in vCenter (created by Packer)"
  type        = string
  default     = "cos-manager-template"
}

variable "cos_accesser_template" {
  description = "Name of Accesser VM template in vCenter (created by Packer)"
  type        = string
  default     = "cos-accesser-template"
}

variable "cos_slicestor_template" {
  description = "Name of Slicestor VM template in vCenter (created by Packer)"
  type        = string
  default     = "cos-slicestor-template"
}

variable "ssh_private_key_path" {
  description = "Path to SSH private key for VM configuration (same key used by Packer)"
  type        = string
  default     = "./packer/packer_rsa"
}

# VM Organization
variable "vm_folder" {
  description = "vCenter folder for COS VMs (will be created if it doesn't exist)"
  type        = string
  default     = "COS-System-1"
}

# Legacy OVA support (deprecated - use Packer templates instead)
variable "ova_directory" {
  description = "Directory containing IBM COS OVA files (deprecated - use Packer templates)"
  type        = string
  default     = "./ova"
}

# COS Default Credentials
variable "cos_default_username" {
  description = "Default username for COS VMs"
  type        = string
  default     = "localadmin"
}

variable "cos_default_password" {
  description = "Default password for COS VMs"
  type        = string
  default     = "password"
  sensitive   = true
}

# Organization Settings
variable "organization_name" {
  description = "Organization name for COS configuration"
  type        = string
  default     = "IBM"
}

variable "country_code" {
  description = "Country code for COS configuration (2-letter ISO code)"
  type        = string
  default     = "DE"

  validation {
    condition     = length(var.country_code) == 2
    error_message = "Country code must be a 2-letter ISO code."
  }
}

# Deployment Options
variable "wait_for_guest_net_timeout" {
  description = "Timeout in minutes to wait for guest network (0 = no wait, VMs configured via SSH)"
  type        = number
  default     = 0
}

variable "auto_configure" {
  description = "Automatically configure COS nodes after deployment"
  type        = bool
  default     = true
}