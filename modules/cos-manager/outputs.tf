#
# Copyright 2024- IBM Inc. All rights reserved
# SPDX-License-Identifier: Apache2.0
#

output "vm_id" {
  description = "ID of the Manager VM"
  value       = vsphere_virtual_machine.manager.id
}

output "vm_name" {
  description = "Name of the Manager VM"
  value       = vsphere_virtual_machine.manager.name
}

output "ip_address" {
  description = "IP address of the Manager VM"
  value       = var.ip_address
}