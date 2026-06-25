#
# Copyright 2024- IBM Inc. All rights reserved
# SPDX-License-Identifier: Apache2.0
#

variable "datacenter_id" {
  description = "vSphere datacenter ID"
  type        = string
}

variable "cluster_id" {
  description = "vSphere cluster ID"
  type        = string
}

variable "datastore_id" {
  description = "vSphere datastore ID"
  type        = string
}

variable "network_id" {
  description = "vSphere network ID"
  type        = string
}

variable "resource_pool_id" {
  description = "vSphere resource pool ID"
  type        = string
}

variable "folder" {
  description = "vSphere folder path for the VM"
  type        = string
}

variable "template_uuid" {
  description = "UUID of the Packer template to clone from"
  type        = string
}

variable "vm_name" {
  description = "Name of the Accesser VM"
  type        = string
}

variable "num_cpus" {
  description = "Number of vCPUs"
  type        = number
}

variable "memory" {
  description = "Memory in MB"
  type        = number
}

variable "disk_size" {
  description = "Boot disk size in GB"
  type        = number
}

variable "template_ip" {
  description = "IP address of the template (will be changed to ip_address)"
  type        = string
}

variable "ip_address" {
  description = "Static IP address for the VM"
  type        = string
}

variable "netmask" {
  description = "Network subnet mask"
  type        = string
}

variable "gateway" {
  description = "Network gateway"
  type        = string
}

variable "dns_servers" {
  description = "DNS servers (comma-separated)"
  type        = string
}

variable "ntp_servers" {
  description = "NTP servers (comma-separated)"
  type        = string
}

variable "hostname" {
  description = "Hostname for the COS Accesser"
  type        = string
}

variable "manager_ip" {
  description = "IP address of the Manager VM"
  type        = string
}

variable "organization" {
  description = "Organization name"
  type        = string
}

variable "country" {
  description = "Country code"
  type        = string
}

variable "ssh_private_key" {
  description = "Path to SSH private key for configuration"
  type        = string
}

variable "wait_for_guest_net_timeout" {
  description = "Timeout in minutes to wait for guest network"
  type        = number
  default     = 0
}
variable "host_system_id" {
  description = "ESXi host ID to pin VM to (optional)"
  type        = string
  default     = null
}
