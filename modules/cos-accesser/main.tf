#
# Copyright 2024- IBM Inc. All rights reserved
# SPDX-License-Identifier: Apache2.0
#

terraform {
  required_providers {
    vsphere = {
      source = "vmware/vsphere"
    }
  }
}

# Deploy Accesser VM by cloning from Packer template
resource "vsphere_virtual_machine" "accesser" {
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
  
  # Boot disk - thick provisioned to match Packer template
  disk {
    label            = "disk0"
    size             = var.disk_size
    thin_provisioned = false
  }
}

# Wait for VM to be accessible via SSH at template IP
resource "null_resource" "wait_for_ssh" {
  depends_on = [vsphere_virtual_machine.accesser]
  
  provisioner "local-exec" {
    command = <<-EOT
      echo "Waiting for Accesser VM to be accessible via SSH at template IP ${var.template_ip}..."
      
      # Source govc environment
      source ${path.root}/scripts/setup-govc-env.sh > /dev/null 2>&1
      
      for i in {1..60}; do
        if ssh -i ${var.ssh_private_key} -o StrictHostKeyChecking=no -o ConnectTimeout=5 localadmin@${var.template_ip} "version" 2>/dev/null | grep -q "ClevOS"; then
          echo "Accesser VM is accessible at ${var.template_ip}"
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

# Configure Accesser VM via SSH (reconfigure network and connect to Manager)
resource "null_resource" "configure_accesser" {
  depends_on = [null_resource.wait_for_ssh]
  
  triggers = {
    vm_id = vsphere_virtual_machine.accesser.id
  }
  
  provisioner "local-exec" {
    command = "${path.root}/scripts/configure-accesser-ssh.sh"
    environment = {
      OLD_IP       = var.template_ip
      NEW_IP       = var.ip_address
      NETMASK      = var.netmask
      GATEWAY      = var.gateway
      DNS_SERVERS  = var.dns_servers
      NTP_SERVERS  = var.ntp_servers
      HOSTNAME     = var.hostname
      MANAGER_IP   = var.manager_ip
      ORGANIZATION = var.organization
      COUNTRY      = var.country
      SSH_KEY      = var.ssh_private_key
    }
  }
}

# Verify Accesser is accessible at new IP
resource "null_resource" "verify_new_ip" {
  depends_on = [null_resource.configure_accesser]
  
  provisioner "local-exec" {
    command = <<-EOT
      echo "Verifying Accesser VM is accessible at new IP ${var.ip_address}..."
      sleep 30
      for i in {1..30}; do
        if ssh -i ${var.ssh_private_key} -o StrictHostKeyChecking=no -o ConnectTimeout=5 localadmin@${var.ip_address} "version" 2>/dev/null; then
          echo "Accesser VM is accessible at ${var.ip_address}"
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