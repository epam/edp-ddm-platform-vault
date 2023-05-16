source "vsphere-iso" "this" {
  vcenter_server          = var.vsphere_server
  username                = var.vsphere_user
  password                = var.vsphere_password
  datacenter              = var.vsphere_datacenter
  resource_pool           = var.vsphere_resource_pool
  folder                  = var.vsphere_folder
  cluster                 = var.vsphere_cluster
  insecure_connection     = true

  vm_name                 = var.vsphere_template_name
  guest_os_type           = "ubuntu64Guest"

  ssh_username            = var.ssh_username
  ssh_password            = var.ssh_password

  CPUs                    = 1
  RAM                     = 1024
  RAM_reserve_all         = true

  disk_controller_type    = ["pvscsi"]
  datastore               = var.vsphere_datastore

  storage {
    disk_size             = 16384
    disk_thin_provisioned = true
  }

  iso_url                 = "https://cdimage.ubuntu.com/ubuntu-legacy-server/releases/20.04/release/ubuntu-20.04.1-legacy-server-amd64.iso"
  iso_checksum            = "f11bda2f2caed8f420802b59f382c25160b114ccc665dbac9c5046e7fceaced2"

  network_adapters {
    network               = var.vsphere_network
    network_card          = "vmxnet3"
  }

  floppy_files = [
    "./preseed.cfg"
  ]

  boot_command = [
    "<enter><wait><f6><wait><esc><wait>",
    "<bs><bs><bs><bs><bs><bs><bs><bs><bs><bs>",
    "<bs><bs><bs><bs><bs><bs><bs><bs><bs><bs>",
    "<bs><bs><bs><bs><bs><bs><bs><bs><bs><bs>",
    "<bs><bs><bs><bs><bs><bs><bs><bs><bs><bs>",
    "<bs><bs><bs><bs><bs><bs><bs><bs><bs><bs>",
    "<bs><bs><bs><bs><bs><bs><bs><bs><bs><bs>",
    "<bs><bs><bs><bs><bs><bs><bs><bs><bs><bs>",
    "<bs><bs><bs><bs><bs><bs><bs><bs><bs><bs>",
    "<bs><bs><bs>",
    "/install/vmlinuz",
    " initrd=/install/initrd.gz",
    " priority=critical",
    " locale=en_US",
    " file=/media/preseed.cfg",
    "<enter>"
  ]
}

build {
  sources = [
    "source.vsphere-iso.this"
  ]

  provisioner "file" {
    destination = "/tmp/public.key"
    source      = "public.key"
  }

  provisioner "shell" {
    inline = [
      "mkdir -p -m 700 /home/${var.ssh_username}/.ssh",
      "cat /tmp/public.key >> /home/${var.ssh_username}/.ssh/authorized_keys",
      "chmod 600 /home/${var.ssh_username}/.ssh/authorized_keys"
    ]
  }
}
