#
# Copyright 2024- IBM Inc. All rights reserved
# SPDX-License-Identifier: Apache2.0
#

# Configure the VMware vSphere Provider
provider "vsphere" {
  user                 = var.vsphere_user
  password             = var.vsphere_password
  vsphere_server       = var.vsphere_server
  allow_unverified_ssl = var.vsphere_allow_unverified_ssl
}

# Data sources for vSphere infrastructure
data "vsphere_datacenter" "dc" {
  name = var.vsphere_datacenter
}

data "vsphere_compute_cluster" "cluster" {
  name          = var.vsphere_cluster
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_datastore" "datastore" {
  name          = var.vsphere_datastore
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_network" "network" {
  name          = var.vsphere_network
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_resource_pool" "pool" {
  name          = var.vsphere_resource_pool != "" ? var.vsphere_resource_pool : "${var.vsphere_cluster}/Resources"
  datacenter_id = data.vsphere_datacenter.dc.id
}

# ESXi host to pin VMs to (optional)
data "vsphere_host" "host" {
  count         = var.vsphere_host != "" ? 1 : 0
  name          = var.vsphere_host
  datacenter_id = data.vsphere_datacenter.dc.id
}

# VM folder for organization
resource "vsphere_folder" "cos_folder" {
  path          = var.vm_folder
  type          = "vm"
  datacenter_id = data.vsphere_datacenter.dc.id
}

# Packer template data sources
data "vsphere_virtual_machine" "manager_template" {
  name          = var.cos_manager_template
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_virtual_machine" "accesser_template" {
  name          = var.cos_accesser_template
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_virtual_machine" "slicestor_template" {
  name          = var.cos_slicestor_template
  datacenter_id = data.vsphere_datacenter.dc.id
}

# Local variables for IP address calculation
locals {
  ip_parts      = split(".", var.base_ip)
  ip_prefix     = join(".", slice(local.ip_parts, 0, 3))
  ip_suffix     = tonumber(local.ip_parts[3])
  
  # Calculate IPs sequentially: Manager, Accesser1, Accesser2, ..., Slicestor1, Slicestor2, ...
  manager_ip    = var.base_ip
  accesser_ips  = [
    for i in range(var.num_accessers) :
    "${local.ip_prefix}.${local.ip_suffix + 1 + i}"
  ]
  
  slicestor_ips = [
    for i in range(var.num_slicestors) :
    "${local.ip_prefix}.${local.ip_suffix + 1 + var.num_accessers + i}"
  ]
  
  # Template IPs (VMs cloned from templates will have these IPs initially)
  manager_template_ip   = "10.33.3.200"
  accesser_template_ip  = "10.33.3.201"
  slicestor_template_ip = "10.33.3.202"
}

# Deploy Manager VM from Packer template
module "cos_manager" {
  source = "./modules/cos-manager"
  
  depends_on = [vsphere_folder.cos_folder]

  # vSphere infrastructure
  datacenter_id    = data.vsphere_datacenter.dc.id
  cluster_id       = data.vsphere_compute_cluster.cluster.id
  datastore_id     = data.vsphere_datastore.datastore.id
  network_id       = data.vsphere_network.network.id
  resource_pool_id = data.vsphere_resource_pool.pool.id
  host_system_id   = var.vsphere_host != "" ? data.vsphere_host.host[0].id : null
  folder           = vsphere_folder.cos_folder.path

  # Template configuration
  template_uuid = data.vsphere_virtual_machine.manager_template.id

  # VM configuration
  vm_name       = "COS${var.system_index}-Manager1"
  num_cpus      = var.manager_cpu
  memory        = var.manager_memory
  disk_size     = var.manager_disk_size

  # Network configuration (template has 10.33.3.200, will be changed to this)
  template_ip     = local.manager_template_ip
  ip_address      = local.manager_ip
  netmask         = var.netmask
  gateway         = var.gateway
  dns_servers     = var.dns_servers
  ntp_servers     = var.ntp_servers

  # COS configuration
  hostname         = "manager"
  organization     = var.organization_name
  country          = var.country_code
  ssh_private_key  = var.ssh_private_key_path

  wait_for_guest_net_timeout = var.wait_for_guest_net_timeout
}

# Deploy Accesser VMs from Packer template (sequentially)
# Each Accesser waits for the previous one to complete to avoid IP conflicts during reconfiguration

# Accesser 1 - deploys after Manager
module "cos_accesser_1" {
  source = "./modules/cos-accesser"
  count  = var.num_accessers >= 1 ? 1 : 0

  depends_on = [module.cos_manager]

  # vSphere infrastructure
  datacenter_id    = data.vsphere_datacenter.dc.id
  cluster_id       = data.vsphere_compute_cluster.cluster.id
  datastore_id     = data.vsphere_datastore.datastore.id
  network_id       = data.vsphere_network.network.id
  resource_pool_id = data.vsphere_resource_pool.pool.id
  host_system_id   = var.vsphere_host != "" ? data.vsphere_host.host[0].id : null
  folder           = vsphere_folder.cos_folder.path

  # Template configuration
  template_uuid = data.vsphere_virtual_machine.accesser_template.id

  # VM configuration
  vm_name       = "COS${var.system_index}-Accesser1"
  num_cpus      = var.accesser_cpu
  memory        = var.accesser_memory
  disk_size     = var.accesser_disk_size

  # Network configuration (template has 10.33.3.201, will be changed to this)
  template_ip     = local.accesser_template_ip
  ip_address      = local.accesser_ips[0]
  netmask         = var.netmask
  gateway         = var.gateway
  dns_servers     = var.dns_servers
  ntp_servers     = var.ntp_servers

  # COS configuration
  hostname         = "accesser1"
  manager_ip       = local.manager_ip
  organization     = var.organization_name
  country          = var.country_code
  ssh_private_key  = var.ssh_private_key_path

  wait_for_guest_net_timeout = var.wait_for_guest_net_timeout
}

# Accesser 2 - deploys after Accesser 1 completes
module "cos_accesser_2" {
  source = "./modules/cos-accesser"
  count  = var.num_accessers >= 2 ? 1 : 0

  depends_on = [module.cos_accesser_1]

  # vSphere infrastructure
  datacenter_id    = data.vsphere_datacenter.dc.id
  cluster_id       = data.vsphere_compute_cluster.cluster.id
  datastore_id     = data.vsphere_datastore.datastore.id
  network_id       = data.vsphere_network.network.id
  resource_pool_id = data.vsphere_resource_pool.pool.id
  host_system_id   = var.vsphere_host != "" ? data.vsphere_host.host[0].id : null
  folder           = vsphere_folder.cos_folder.path

  # Template configuration
  template_uuid = data.vsphere_virtual_machine.accesser_template.id

  # VM configuration
  vm_name       = "COS${var.system_index}-Accesser2"
  num_cpus      = var.accesser_cpu
  memory        = var.accesser_memory
  disk_size     = var.accesser_disk_size

  # Network configuration (template has 10.33.3.201, will be changed to this)
  template_ip     = local.accesser_template_ip
  ip_address      = local.accesser_ips[1]
  netmask         = var.netmask
  gateway         = var.gateway
  dns_servers     = var.dns_servers
  ntp_servers     = var.ntp_servers

  # COS configuration
  hostname         = "accesser2"
  manager_ip       = local.manager_ip
  organization     = var.organization_name
  country          = var.country_code
  ssh_private_key  = var.ssh_private_key_path

  wait_for_guest_net_timeout = var.wait_for_guest_net_timeout
}

# Accesser 3 - deploys after Accesser 2 completes
module "cos_accesser_3" {
  source = "./modules/cos-accesser"
  count  = var.num_accessers >= 3 ? 1 : 0

  depends_on = [module.cos_accesser_2]

  # vSphere infrastructure
  datacenter_id    = data.vsphere_datacenter.dc.id
  cluster_id       = data.vsphere_compute_cluster.cluster.id
  datastore_id     = data.vsphere_datastore.datastore.id
  network_id       = data.vsphere_network.network.id
  resource_pool_id = data.vsphere_resource_pool.pool.id
  host_system_id   = var.vsphere_host != "" ? data.vsphere_host.host[0].id : null
  folder           = vsphere_folder.cos_folder.path

  # Template configuration
  template_uuid = data.vsphere_virtual_machine.accesser_template.id

  # VM configuration
  vm_name       = "COS${var.system_index}-Accesser3"
  num_cpus      = var.accesser_cpu
  memory        = var.accesser_memory
  disk_size     = var.accesser_disk_size

  # Network configuration (template has 10.33.3.201, will be changed to this)
  template_ip     = local.accesser_template_ip
  ip_address      = local.accesser_ips[2]
  netmask         = var.netmask
  gateway         = var.gateway
  dns_servers     = var.dns_servers
  ntp_servers     = var.ntp_servers

  # COS configuration
  hostname         = "accesser3"
  manager_ip       = local.manager_ip
  organization     = var.organization_name
  country          = var.country_code
  ssh_private_key  = var.ssh_private_key_path

  wait_for_guest_net_timeout = var.wait_for_guest_net_timeout
}

# Deploy Slicestor VMs from Packer template (sequentially)
# Each Slicestor waits for the previous one to complete to avoid IP conflicts during reconfiguration

# Slicestor 1 - deploys after last Accesser
module "cos_slicestor_1" {
  source = "./modules/cos-slicestor"
  count  = var.num_slicestors >= 1 ? 1 : 0

  depends_on = [
    module.cos_accesser_1,
    module.cos_accesser_2,
    module.cos_accesser_3
  ]

  # vSphere infrastructure
  datacenter_id    = data.vsphere_datacenter.dc.id
  cluster_id       = data.vsphere_compute_cluster.cluster.id
  datastore_id     = data.vsphere_datastore.datastore.id
  network_id       = data.vsphere_network.network.id
  resource_pool_id = data.vsphere_resource_pool.pool.id
  host_system_id   = var.vsphere_host != "" ? data.vsphere_host.host[0].id : null
  folder           = vsphere_folder.cos_folder.path

  # Template configuration
  template_uuid = data.vsphere_virtual_machine.slicestor_template.id

  # VM configuration
  vm_name       = "COS${var.system_index}-Slicestor1"
  num_cpus      = var.slicestor_cpu
  memory        = var.slicestor_memory
  disk_size     = var.slicestor_disk_size

  # Storage configuration
  data_disk_count = var.slicestor_data_disk_count
  data_disk_size  = var.slicestor_data_disk_size

  # Network configuration
  template_ip     = local.slicestor_template_ip
  ip_address      = local.slicestor_ips[0]
  netmask         = var.netmask
  gateway         = var.gateway
  dns_servers     = var.dns_servers
  ntp_servers     = var.ntp_servers

  # COS configuration
  hostname         = "slicestor1"
  slicestor_number = 1
  manager_ip       = local.manager_ip
  organization     = var.organization_name
  country          = var.country_code
  ssh_private_key  = var.ssh_private_key_path
  deployment_index = 0

  wait_for_guest_net_timeout = var.wait_for_guest_net_timeout
}

# Slicestor 2 - deploys after Slicestor 1 completes
module "cos_slicestor_2" {
  source = "./modules/cos-slicestor"
  count  = var.num_slicestors >= 2 ? 1 : 0

  depends_on = [module.cos_slicestor_1]

  # vSphere infrastructure
  datacenter_id    = data.vsphere_datacenter.dc.id
  cluster_id       = data.vsphere_compute_cluster.cluster.id
  datastore_id     = data.vsphere_datastore.datastore.id
  network_id       = data.vsphere_network.network.id
  resource_pool_id = data.vsphere_resource_pool.pool.id
  host_system_id   = var.vsphere_host != "" ? data.vsphere_host.host[0].id : null
  folder           = vsphere_folder.cos_folder.path

  # Template configuration
  template_uuid = data.vsphere_virtual_machine.slicestor_template.id

  # VM configuration
  vm_name       = "COS${var.system_index}-Slicestor2"
  num_cpus      = var.slicestor_cpu
  memory        = var.slicestor_memory
  disk_size     = var.slicestor_disk_size

  # Storage configuration
  data_disk_count = var.slicestor_data_disk_count
  data_disk_size  = var.slicestor_data_disk_size

  # Network configuration
  template_ip     = local.slicestor_template_ip
  ip_address      = local.slicestor_ips[1]
  netmask         = var.netmask
  gateway         = var.gateway
  dns_servers     = var.dns_servers
  ntp_servers     = var.ntp_servers

  # COS configuration
  hostname         = "slicestor2"
  slicestor_number = 2
  manager_ip       = local.manager_ip
  organization     = var.organization_name
  country          = var.country_code
  ssh_private_key  = var.ssh_private_key_path
  deployment_index = 1

  wait_for_guest_net_timeout = var.wait_for_guest_net_timeout
}

# Slicestor 3 - deploys after Slicestor 2 completes
module "cos_slicestor_3" {
  source = "./modules/cos-slicestor"
  count  = var.num_slicestors >= 3 ? 1 : 0

  depends_on = [module.cos_slicestor_2]

  # vSphere infrastructure
  datacenter_id    = data.vsphere_datacenter.dc.id
  cluster_id       = data.vsphere_compute_cluster.cluster.id
  datastore_id     = data.vsphere_datastore.datastore.id
  network_id       = data.vsphere_network.network.id
  resource_pool_id = data.vsphere_resource_pool.pool.id
  host_system_id   = var.vsphere_host != "" ? data.vsphere_host.host[0].id : null
  folder           = vsphere_folder.cos_folder.path

  # Template configuration
  template_uuid = data.vsphere_virtual_machine.slicestor_template.id

  # VM configuration
  vm_name       = "COS${var.system_index}-Slicestor3"
  num_cpus      = var.slicestor_cpu
  memory        = var.slicestor_memory
  disk_size     = var.slicestor_disk_size

  # Storage configuration
  data_disk_count = var.slicestor_data_disk_count
  data_disk_size  = var.slicestor_data_disk_size

  # Network configuration
  template_ip     = local.slicestor_template_ip
  ip_address      = local.slicestor_ips[2]
  netmask         = var.netmask
  gateway         = var.gateway
  dns_servers     = var.dns_servers
  ntp_servers     = var.ntp_servers

  # COS configuration
  hostname         = "slicestor3"
  slicestor_number = 3
  manager_ip       = local.manager_ip
  organization     = var.organization_name
  country          = var.country_code
  ssh_private_key  = var.ssh_private_key_path
  deployment_index = 2

  wait_for_guest_net_timeout = var.wait_for_guest_net_timeout
}