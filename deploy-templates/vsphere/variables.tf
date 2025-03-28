variable "vsphere_server" {
  description = "vSphere server"
  type        = string
}

variable "vsphere_user" {
  description = "vSphere username"
  type        = string
}

variable "vsphere_password" {
  description = "vSphere password"
  type        = string
  sensitive   = true
}

variable "vsphere_datacenter" {
  description = "vSphere data center"
  type        = string
}

variable "vsphere_cluster" {
  description = "vSphere cluster"
  type        = string
}

variable "vsphere_datastore" {
  description = "vSphere datastore"
  type        = string
}

variable "vsphere_network" {
  description = "vSphere network name"
  type        = string
}

variable "vsphere_folder" {
  description = "Vsphere folder"
  type        = string
}

variable "vsphere_network_gateway" {
  description = "Vsphere network gateway IP"
  type        = string
}

variable "vsphere_resource_pool" {
  description = "Vsphere resource pool"
  type        = string
}

variable "cluster_name" {
  description = "OKD cluster name"
  type        = string
  default     = "main"
}

variable "baseDomain" {
  description = "baseDomain"
  type        = string
}

variable "vsphere_vault_instance_ip" {
  description = "Vault Instance IP address"
  type        = string
}

variable "vsphere_vault_volume_os_size" {
  description = "minimum size of the OS disk [GiB]"
  type        = number
  default     = 32
  validation {
    condition     = var.vsphere_vault_volume_os_size >= 32
    error_message = "Must be 32 or more."
  }
}

variable "vsphere_vault_volume_size" {
  type        = string
  description = "Default data volumes size for storage"
  default     = 50
}

variable "vsphere_vault_template_name" {
  description = "vault template name"
  type        = string
  default     = "vault-ubuntu-template"
}

variable "wait_for_cluster_cmd" {
  description = "Custom local-exec command to execute for determining if the eks cluster is healthy. Cluster endpoint will be available as an environment variable called ENDPOINT"
  type        = string
  default     = "for i in seq 1 60; do curl -I $ENDPOINT >/dev/null && exit 0 || true; sleep 30; done; echo TIMEOUT && exit 1"
}

variable "wait_for_cluster_interpreter" {
  description = "Custom local-exec command line interpreter for the command to determining if the eks cluster is healthy."
  type        = list(string)
  default     = ["/bin/sh", "-c"]
}

variable "vault_url" {
  type    = string
  default = "https://releases.hashicorp.com/vault/1.6.0/vault_1.6.0_linux_amd64.zip"
}

variable "vault_volume_path" {
  type    = string
  default = "/dev/sdb"
}

variable "vault_local_mount_path" {
  type    = string
  default = "/apps"
}

variable "connection_timeout" {
  description = "Timeout for connections to Vault"
  type        = number
  default     = 200
}