provider "vsphere" {
  vsphere_server = var.vsphere_server
  user           = var.vsphere_user
  password       = var.vsphere_password

  allow_unverified_ssl = true
}

data "vsphere_datacenter" "dc" {
  name = var.vsphere_datacenter
}

data "vsphere_datastore" "datastore" {
  name          = var.vsphere_datastore
  datacenter_id = "${data.vsphere_datacenter.dc.id}"
}

data "vsphere_compute_cluster" "cluster" {
  name          = var.vsphere_cluster
  datacenter_id = "${data.vsphere_datacenter.dc.id}"
}

data "vsphere_network" "network" {
  name          = var.vsphere_network
  datacenter_id = "${data.vsphere_datacenter.dc.id}"
}

data "vsphere_virtual_machine" "template" {
  name          = "template-vault"
  datacenter_id = "${data.vsphere_datacenter.dc.id}"
}

data "vsphere_resource_pool" "pool" {
  name          = "${var.vsphere_cluster}/Resources/${var.vsphere_resource_pool}"
  datacenter_id = "${data.vsphere_datacenter.dc.id}"
}

resource "vsphere_virtual_machine" "vm" {
  name             = "platform-vault-${var.cluster_name}"
  resource_pool_id = "${data.vsphere_resource_pool.pool.id}"
  datastore_id     = "${data.vsphere_datastore.datastore.id}"
  folder           = "${var.vsphere_datacenter}/vm/${var.vsphere_folder}"

  num_cpus = 2
  memory   = 2048
  guest_id = "${data.vsphere_virtual_machine.template.guest_id}"
  wait_for_guest_net_timeout = -1

  scsi_type = "${data.vsphere_virtual_machine.template.scsi_type}"

  network_interface {
    network_id   = data.vsphere_network.network.id
  } 
  disk {
    label            = "disk0"
    size             = "${data.vsphere_virtual_machine.template.disks.0.size}"
    eagerly_scrub    = "${data.vsphere_virtual_machine.template.disks.0.eagerly_scrub}"
    thin_provisioned = "${data.vsphere_virtual_machine.template.disks.0.thin_provisioned}"
  }

  clone {
    template_uuid = "${data.vsphere_virtual_machine.template.id}"

customize {
      linux_options {
        host_name = "platform-vault-${var.cluster_name}"
        domain    = var.baseDomain
      }
      network_interface {
        ipv4_address = var.vsphere_vault_instance_ip
        ipv4_netmask = 24
      }

      ipv4_gateway = "${var.vsphere_network_gateway}"
    }
  }

  lifecycle {
    ignore_changes = [
      change_version,
      imported,
      storage_policy_id,
    ]
  }

}

output "test_ip" {
  value = "${vsphere_virtual_machine.vm.default_ip_address}"
}

resource "null_resource" "vault_init" {
  provisioner "local-exec" {
    command     = var.wait_for_cluster_cmd
    interpreter = var.wait_for_cluster_interpreter
    environment = {
      ENDPOINT = "http://${var.vsphere_vault_instance_ip}:8200/"
    }
  }
  depends_on = [vsphere_virtual_machine.vm]
}

module "files" {
   source  = "github.com/matti/terraform-shell-outputs.git"
  command = "sleep 80 && ssh -o \"StrictHostKeyChecking no\" vault@${var.vsphere_vault_instance_ip} -i packer/private.key cat /opt/vault/keys | grep Root | awk -F : {'print $2'} | cut -c2-"
  depends_on = [null_resource.vault_init]
}
