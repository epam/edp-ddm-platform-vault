variable "aws_region" {
  default = "eu-central-1"
}

variable "aws_zone" {
  default = "eu-central-1b"
}

variable "vault_url" {
  default = "https://releases.hashicorp.com/vault/1.6.0/vault_1.6.0_linux_amd64.zip"
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR of the VPC"
  default     = "192.168.100.0/24"
}

variable "cluster_name" {
  type        = string
  description = "Cluster name"
  default     = "main"
}

variable "custom_ingress_rules_cidrs" {
  description = <<EOD
List of CIDRs for ingress rules. |
**Optional** |
```
["85.223.209.0/24"]
```
EOD
  type        = list(any)
  default     = ["85.223.209.0/24"]
}

variable "wait_for_cluster_interpreter" {
  description = "Custom local-exec command line interpreter for the command to determining if the eks cluster is healthy."
  type        = list(string)
  default     = ["/bin/sh", "-c"]
}

variable "baseDomain" {
  description = "baseDomain"
  type        = string
  default     = "mdtu-ddm.projects.epam.com"
}

variable "ssh_user" {
  description = <<EOD
The user to access server over ssh. |
**Optional** |
EOD
  type        = string
  default     = "ubuntu"
}

variable "enable-vault_data-migration_to_ebs" {
  description = <<EOD
Enable and disable remote-exec to migrate vault data to ebs volume. |
**Optional** |
EOD
  type        = bool
  default     = true
}

variable "ebs_iops" {
  description = <<EOD
The amount of IOPS to provision for the disk. |
Only valid for `type` of `io1`, `io2` or `gp3`. |
The details you can find [here](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ebs-volume-types.html). |
**Optional** |
EOD
  type        = number
  default     = 0
}

variable "ebs_size" {
  description = <<EOD
The size of the drive in GiBs. |
**Optional** |
EOD
  type        = number
  default     = 10
}

variable "ebs_throughput" {
  description = <<EOD
The throughput that the volume supports, in MiB/s. |
Only valid for `type` of `gp3`. |
The details you can find [here](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ebs-volume-types.html). |
**Optional** |
EOD
  type        = number
  default     = 200
}

variable "ebs_type" {
  description = <<EOD
The type of EBS volume. Can be standard, `gp2`, `gp3`, `io1`, `io2`, `sc1` or `st1`. |
The details you can find [here](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ebs-volume-types.html). |
**Optional** |
EOD
  type        = string
  default     = "gp3"
}

variable "vault_volume_mount_path" {
  description = <<EOD
The device name to expose to the instance (for example, /dev/sdh or xvdh). |
See Device Naming on [Linux Instances](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/device_naming.html#available-ec2-device-names) for more information. |
**Optional** |
EOD
  type        = string
  default     = "/dev/xvdh"
}

variable "vault_local_mount_path" {
  description = <<EOD
The local path to be used to mount volume. |
**Optional** |
EOD
  type        = string
  default     = "/apps"
}

variable "connection_timeout" {
  description = <<EOD
The amount of seconds while terraform will attempt to connect to the host to complete null resources. |
**Optional** |
EOD
  type        = number
  default     = 600
}

variable "tags" {
  type        = map(any)
  description = "A map of tags to add to all resources."
}