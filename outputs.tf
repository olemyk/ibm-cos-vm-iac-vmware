#
# Copyright 2024- IBM Inc. All rights reserved
# SPDX-License-Identifier: Apache2.0
#

output "manager_ip" {
  description = "IP address of the Manager VM"
  value       = local.manager_ip
}

output "manager_vm_name" {
  description = "Name of the Manager VM"
  value       = module.cos_manager.vm_name
}

output "accesser_ips" {
  description = "IP addresses of the Accesser VMs"
  value       = local.accesser_ips
}

output "accesser_vm_names" {
  description = "Names of the Accesser VMs"
  value = compact([
    var.num_accessers >= 1 ? module.cos_accesser_1[0].vm_name : "",
    var.num_accessers >= 2 ? module.cos_accesser_2[0].vm_name : "",
    var.num_accessers >= 3 ? module.cos_accesser_3[0].vm_name : "",
  ])
}

output "slicestor_ips" {
  description = "IP addresses of the Slicestor VMs"
  value       = local.slicestor_ips
}

output "slicestor_vm_names" {
  description = "Names of the Slicestor VMs"
  value = compact([
    var.num_slicestors >= 1 ? module.cos_slicestor_1[0].vm_name : "",
    var.num_slicestors >= 2 ? module.cos_slicestor_2[0].vm_name : "",
    var.num_slicestors >= 3 ? module.cos_slicestor_3[0].vm_name : "",
  ])
}

output "manager_url" {
  description = "URL to access the IBM COS Manager web interface"
  value       = "https://${local.manager_ip}"
}

output "deployment_summary" {
  description = "Summary of the deployed IBM COS system"
  value = {
    system_index     = var.system_index
    cos_version      = var.cos_version
    manager_ip       = local.manager_ip
    accesser_count   = var.num_accessers
    accesser_ips     = local.accesser_ips
    slicestor_count  = var.num_slicestors
    slicestor_ips    = local.slicestor_ips
    manager_url      = "https://${local.manager_ip}"
  }
}