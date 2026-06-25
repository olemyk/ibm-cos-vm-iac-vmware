#
# Copyright 2024- IBM Inc. All rights reserved
# SPDX-License-Identifier: Apache2.0
#

output "vm_id" {
  description = "ID of the Slicestor VM"
  value       = vsphere_virtual_machine.slicestor.id
}

output "vm_name" {
  description = "Name of the Slicestor VM"
  value       = vsphere_virtual_machine.slicestor.name
}

output "ip_address" {
  description = "IP address of the Slicestor VM"
  value       = var.ip_address
}