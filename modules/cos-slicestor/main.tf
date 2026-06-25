#
# Copyright 2024- IBM Inc. All rights reserved
# SPDX-License-Identifier: Apache2.0
#

# Deploy Slicestor VM by cloning from Packer template
resource "vsphere_virtual_machine" "slicestor" {
  name             = var.vm_name
  resource_pool_id = var.resource_pool_id
  datastore_id     = var.datastore_id
  host_system_id   = var.host_system_id
  folder           = var.folder
  
  num_cpus = var.num_cpus
  memory   = var.memory
  guest_id = "other3xLinux64Guest"
  
  wait_for_guest_net_timeout = var.wait_for_guest_net_timeout
  
  network_interface {
    network_id = var.network_id
  }
  
  # Clone from Packer template
  clone {
    template_uuid = var.template_uuid
  }
  
  # Boot disk (resize if needed)
  disk {
    label = "disk0"
    size  = var.disk_size
  }
  
  # Add data disks for storage (Thick Provision Lazy Zeroed)
  # Default: 12 x 16GB data disks (minimum 12 for storage pool width 3)
  dynamic "disk" {
    for_each = range(var.data_disk_count)
    content {
      label            = "disk${disk.key + 1}"
      size             = var.data_disk_size
      unit_number      = disk.key + 1
      thin_provisioned = false  # Thick Provision Lazy Zeroed
    }
  }
}

# Wait for VM to be accessible via SSH at template IP
resource "null_resource" "wait_for_ssh" {
  depends_on = [vsphere_virtual_machine.slicestor]
  
  provisioner "local-exec" {
    command = <<-EOT
      echo "Waiting for Slicestor VM ${var.vm_name} to be accessible via SSH at template IP ${var.template_ip}..."
      
      # Source govc environment
      source ${path.root}/scripts/setup-govc-env.sh > /dev/null 2>&1
      
      for i in {1..60}; do
        if ssh -i ${var.ssh_private_key} -o StrictHostKeyChecking=no -o ConnectTimeout=5 localadmin@${var.template_ip} "version" 2>/dev/null | grep -q "ClevOS"; then
          echo "Slicestor VM is accessible at ${var.template_ip}"
          exit 0
        fi
        echo "Waiting for SSH (attempt $i/60)..."
        
        # Every 10 attempts, check if VM is pingable and restart if not
        if [ $((i % 10)) -eq 0 ]; then
          echo "Checking VM connectivity..."
          if ! ping -c 2 -W 2 ${var.template_ip} > /dev/null 2>&1; then
            echo "VM not responding to ping. Restarting VM..."
            govc vm.power -reset -force ${var.folder}/${var.vm_name}
            echo "Waiting 30 seconds for VM to restart..."
            sleep 30
          else
            echo "VM is pingable but SSH not ready yet"
          fi
        fi
        
        sleep 10
      done
      echo "Timeout waiting for SSH after 60 attempts"
      exit 1
    EOT
  }
}

# Configure Slicestor VM via SSH (reconfigure network and connect to Manager)
resource "null_resource" "configure_slicestor" {
  depends_on = [null_resource.wait_for_ssh]
  
  triggers = {
    vm_id = vsphere_virtual_machine.slicestor.id
  }
  
  provisioner "local-exec" {
    command = "${path.root}/scripts/configure-slicestor-ssh.sh"
    environment = {
      OLD_IP           = var.template_ip
      NEW_IP           = var.ip_address
      NETMASK          = var.netmask
      GATEWAY          = var.gateway
      DNS_SERVERS      = var.dns_servers
      NTP_SERVERS      = var.ntp_servers
      HOSTNAME         = var.hostname
      SLICESTOR_NUMBER = var.slicestor_number
      MANAGER_IP       = var.manager_ip
      ORGANIZATION     = var.organization
      COUNTRY          = var.country
      SSH_KEY          = var.ssh_private_key
    }
  }
}

# Verify Slicestor is accessible at new IP
resource "null_resource" "verify_new_ip" {
  depends_on = [null_resource.configure_slicestor]
  
  provisioner "local-exec" {
    command = <<-EOT
      echo "Verifying Slicestor VM is accessible at new IP ${var.ip_address}..."
      sleep 30
      for i in {1..30}; do
        if ssh -i ${var.ssh_private_key} -o StrictHostKeyChecking=no -o ConnectTimeout=5 localadmin@${var.ip_address} "version" 2>/dev/null; then
          echo "Slicestor VM #${var.slicestor_number} is accessible at ${var.ip_address}"
          exit 0
        fi
        echo "Attempt $i: Waiting for new IP..."
        sleep 10
      done
      echo "Warning: Could not verify new IP, but continuing..."
      exit 0
    EOT
  }
}