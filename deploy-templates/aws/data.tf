data "http" "external_ip" {
  url = "http://ipv4.icanhazip.com"
}

data "aws_ami" "ubuntu" {
  most_recent = "true"
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "vault-kms-unseal" {
  statement {
    sid       = "VaultKMSUnseal"
    effect    = "Allow"
    resources = ["*"]

    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:DescribeKey",
    ]
  }
}

data "aws_nat_gateway" "cluster_ip" {
  filter {
    name   = "tag:Name"
    values = ["${var.cluster_name}-*"]
  }
}

data "template_file" "vault" {
  template = file("./scripts/userdata.tpl")

  vars = {
    kms_key                 = aws_kms_key.vault.id
    vault_url               = var.vault_url
    aws_region              = var.aws_region
    vault_local_mount_path  = var.vault_local_mount_path
    vault_volume_mount_path = var.vault_volume_mount_path
  }
}

data "template_file" "backup_and_migrate_data" {
  template = file("./scripts/backup_and_migrate.tpl")

  vars = {
    kms_key                 = aws_kms_key.vault.id
    vault_url               = var.vault_url
    aws_region              = var.aws_region
    vault_local_mount_path  = var.vault_local_mount_path
    vault_volume_mount_path = var.vault_volume_mount_path
  }
}
