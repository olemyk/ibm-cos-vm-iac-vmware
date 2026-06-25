#
# Copyright 2024- IBM Inc. All rights reserved
# SPDX-License-Identifier: Apache2.0
#

output "vm_id" {
  description = "ID of the Accesser VM"
  value       = vsphere_virtual_machine.accesser.id
}

output "vm_name" {
  description = "Name of the Accesser VM"
  value       = vsphere_virtual_machine.accesser.name
}

output "ip_address" {
  description = "IP address of the Accesser VM"
  value       = var.ip_address
}