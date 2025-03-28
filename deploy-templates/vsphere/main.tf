resource "vsphere_virtual_disk" "virtual_disk" {
  size               = var.vsphere_vault_volume_size
  type               = "thin"
  vmdk_path          = "${var.vsphere_folder}-platform-vault/${var.cluster_name}-platform-vault-volume.vmdk"
  create_directories = true
  datacenter         = data.vsphere_datacenter.dc.name
  datastore          = data.vsphere_datastore.datastore.name
}

resource "vsphere_virtual_machine" "vm" {
  name                       = "${var.cluster_name}-platform-vault"
  resource_pool_id           = data.vsphere_resource_pool.pool.id
  datastore_id               = data.vsphere_datastore.datastore.id
  folder                     = var.vsphere_folder
  num_cpus                   = 4
  memory                     = 8192
  guest_id                   = data.vsphere_virtual_machine.template.guest_id
  wait_for_guest_net_timeout = -1
  scsi_type                  = data.vsphere_virtual_machine.template.scsi_type

  network_interface {
    network_id = data.vsphere_network.network.id
  }

  disk {
    unit_number      = 0
    label            = "disk0"
    size             = var.vsphere_vault_volume_os_size
    thin_provisioned = true
  }

  disk {
    attach       = true
    unit_number  = 1
    label        = "disk1"
    path         = vsphere_virtual_disk.virtual_disk.vmdk_path
    datastore_id = data.vsphere_datastore.datastore.id
  }

  clone {
    template_uuid = data.vsphere_virtual_machine.template.id

    customize {
      linux_options {
        host_name = "${var.cluster_name}-platform-vault"
        domain    = var.baseDomain
      }
      network_interface {
        ipv4_address = var.vsphere_vault_instance_ip
        ipv4_netmask = 24
      }

      ipv4_gateway = var.vsphere_network_gateway
    }
  }
}

resource "null_resource" "vault_userdata" {
  triggers = {
    always_run = "${timestamp()}"
  }

  connection {
    type        = "ssh"
    user        = "mdtuddm"
    private_key = "${file("packer/private.key")}"
    host        = var.vsphere_vault_instance_ip
  }

  provisioner "file" {
    source      = "./scripts/userdata.sh"
    destination = "/tmp/userdata.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "export vault_url=${var.vault_url}",
      "export vault_volume_path=${var.vault_volume_path}",
      "export vault_local_mount_path=${var.vault_local_mount_path}",
      "chmod +x /tmp/userdata.sh",
      "sudo -E /tmp/userdata.sh"
    ]
  }

  depends_on = [vsphere_virtual_machine.vm]
}

resource "null_resource" "vault_unseal" {
  triggers = {
    always_run = "${timestamp()}"
  }

  connection {
    type        = "ssh"
    user        = "mdtuddm"
    private_key = "${file("packer/private.key")}"
    host        = var.vsphere_vault_instance_ip
  }

  provisioner "file" {
    source      = "./scripts/autounseal.sh"
    destination = "/tmp/autounseal.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "export vault_local_mount_path=${var.vault_local_mount_path}",
      "chmod +x /tmp/autounseal.sh",
      "sudo -E /tmp/autounseal.sh"
    ]
  }

  depends_on = [null_resource.vault_userdata]
}

resource "null_resource" "vault_init" {
  triggers = {
    always_run = "${timestamp()}"
  }

  provisioner "local-exec" {
    command     = var.wait_for_cluster_cmd
    interpreter = var.wait_for_cluster_interpreter
    environment = {
      ENDPOINT = "http://${var.vsphere_vault_instance_ip}:8200"
    }
  }
  depends_on = [null_resource.vault_unseal]
}

module "files" {
  source  = "github.com/matti/terraform-shell-outputs.git"
  command = "ssh -o \"StrictHostKeyChecking no\" mdtuddm@${var.vsphere_vault_instance_ip} -i packer/private.key cat ${var.vault_local_mount_path}/vault/keys | grep Root | awk -F : {'print $2'} | cut -c2-"
  depends_on = [null_resource.vault_init]
}

module "kes_role_id" {
  source     = "github.com/matti/terraform-shell-outputs.git"
  command    = <<EOT
          timeout ${var.connection_timeout}s bash -c '
          while ! nc -w 2 ${var.vsphere_vault_instance_ip} 22 > /dev/null ; do
              sleep 5;
          done' && ssh -o 'StrictHostKeyChecking no' \
                 -o 'ConnectionAttempts 5' \
                 -i ./packer/private.key  mdtuddm@${var.vsphere_vault_instance_ip} \
                  timeout ${var.connection_timeout}s bash -c '
          while [ ! -e ${var.vault_local_mount_path}/vault/kes_role_id ] ; do
              sleep 5;
          done' && ssh -o "StrictHostKeyChecking no" \
                       -o "ConnectionAttempts 5" \
                       -i ./packer/private.key  \
                       mdtuddm@${var.vsphere_vault_instance_ip} \
                       cat ${var.vault_local_mount_path}/vault/kes_role_id
          '
  EOT
  depends_on = [null_resource.vault_init]
}

module "kes_secret_id" {
  source     = "github.com/matti/terraform-shell-outputs.git"
  command    = <<EOT
          timeout ${var.connection_timeout}s bash -c '
          while ! nc -w 2 ${var.vsphere_vault_instance_ip} 22 > /dev/null ; do
              sleep 5;
          done' && ssh -o 'StrictHostKeyChecking no' \
                 -o 'ConnectionAttempts 5' \
                 -i ./packer/private.key   mdtuddm@${var.vsphere_vault_instance_ip} \
                  timeout ${var.connection_timeout}s bash -c '
          while [ ! -e ${var.vault_local_mount_path}/vault/kes_secret_id ] ; do
              sleep 5;
          done' && ssh -o "StrictHostKeyChecking no" \
                       -o "ConnectionAttempts 5" \
                       -i ./packer/private.key  \
                       mdtuddm@${var.vsphere_vault_instance_ip} \
                       cat ${var.vault_local_mount_path}/vault/kes_secret_id
          '
  EOT
  depends_on = [null_resource.vault_init]
}
