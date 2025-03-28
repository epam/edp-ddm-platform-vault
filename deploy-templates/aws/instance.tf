resource "aws_kms_key" "vault" {
  description             = "Vault unseal key"
  deletion_window_in_days = 10

  tags = merge(local.tags, {
    "Name" = "platform-vault-${var.cluster_name}"
  })
}

resource "aws_instance" "vault" {

  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public_subnet.id
  key_name      = aws_key_pair.main.key_name
  monitoring    = "false"

  vpc_security_group_ids = [
    aws_security_group.vault.id,
  ]

  ebs_optimized        = false
  iam_instance_profile = aws_iam_instance_profile.vault-kms-unseal.id

  metadata_options {
    http_tokens = "required"
  }

  tags = merge(local.tags, {
    "Name" = "platform-vault-${var.cluster_name}"
  })

  user_data = templatefile("${path.module}/scripts/userdata.tpl", {
    kms_key                 = aws_kms_key.vault.id
    vault_url               = var.vault_url
    aws_region              = var.aws_region
    vault_local_mount_path  = var.vault_local_mount_path
    vault_volume_mount_path = var.vault_volume_mount_path
  })

}

resource "aws_security_group" "vault" {
  name        = "vault-kms-unseal-${var.cluster_name}"
  description = "vault access"
  vpc_id      = aws_vpc.vpc.id

  tags = merge(local.tags, {
    "Name" = "platform-vault-${var.cluster_name}"
  })

  ingress {
    from_port   = 8200
    to_port     = 8200
    protocol    = "tcp"
    cidr_blocks = ["${data.aws_nat_gateway.cluster_ip.public_ip}/32"]
  }

  ingress {
    from_port   = 8200
    to_port     = 8200
    protocol    = "tcp"
    cidr_blocks = ["${chomp(data.http.external_ip.response_body)}/32"]
  }

  ingress {
    from_port   = 8200
    to_port     = 8200
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${chomp(data.http.external_ip.response_body)}/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "null_resource" "user_data_status_check" {
  provisioner "remote-exec" {
    connection {
      host        = aws_eip.vault_ip.public_ip
      user        = "ubuntu"
      private_key = file("./private.key")
    }

    inline = ["echo 'You shall pass!'"]
  }

  provisioner "local-exec" {
    on_failure  = fail
    interpreter = ["/bin/bash", "-c"]
    command     = <<EOT
          echo -e "\x1B[31m Little warm up \x1B[0m"
          timeout ${var.connection_timeout}s bash -c 'while ! nc -w 2 ${aws_eip.vault_ip.public_ip} 22 > /dev/null ; do echo \"Waiting for port SSH open\"; sleep 5; done' \
          && ssh -o 'StrictHostKeyChecking no' -o 'ConnectionAttempts 5' -i private.key  ubuntu@${aws_eip.vault_ip.public_ip} timeout ${var.connection_timeout}s bash -c "'while [ ! -e /tmp/signal ] ; do echo "user_data signal has not found yet"; sleep 5; done'"
          if [ $? -eq 0 ]; then
          echo "user data sucessfully executed"
          else
            echo "Failed to execute user data"
          fi
     EOT
  }
  depends_on = [aws_instance.vault]
}

resource "null_resource" "vault_init" {
  provisioner "local-exec" {
    command     = local.wait_for_cluster_cmd
    interpreter = var.wait_for_cluster_interpreter
    environment = {
      ENDPOINT = "http://${aws_eip.vault_ip.public_ip}:8200/"
    }
  }
  depends_on = [null_resource.user_data_status_check]
}

resource "null_resource" "backup_and_migrate_vault_data" {
  count = var.enable-vault_data-migration_to_ebs ? 1 : 0

  provisioner "remote-exec" {
    inline = [templatefile("${path.module}/scripts/backup_and_migrate.tpl", {
      kms_key                 = aws_kms_key.vault.id
      vault_url               = var.vault_url
      aws_region              = var.aws_region
      vault_local_mount_path  = var.vault_local_mount_path
      vault_volume_mount_path = var.vault_volume_mount_path
    })]

    connection {
      type        = "ssh"
      host        = aws_eip.vault_ip.public_ip
      user        = var.ssh_user
      private_key = tls_private_key.main.private_key_pem
    }
  }

  depends_on = [
    aws_instance.vault,
    aws_volume_attachment.vault_ebs,
    null_resource.user_data_status_check
  ]
}

module "root_token" {
  source     = "github.com/matti/terraform-shell-outputs.git"
  command    = "timeout ${var.connection_timeout}s bash -c 'while ! nc -w 2 ${aws_eip.vault_ip.public_ip} 22 > /dev/null ; do echo \"Waiting for SSH port open\" > /dev/null; sleep 5; done' && ssh -o \"StrictHostKeyChecking no\" -o 'ConnectionAttempts 5' ubuntu@${aws_eip.vault_ip.public_ip} -i private.key cat ${var.vault_local_mount_path}/vault/keys | grep Root | awk -F : {'print $2'} | cut -c2-"
  depends_on = [null_resource.vault_init]
}

module "kes_role_id" {
  source     = "github.com/matti/terraform-shell-outputs.git"
  command    = <<EOT
          timeout ${var.connection_timeout}s bash -c '
          while ! nc -w 2 ${aws_eip.vault_ip.public_ip} 22 > /dev/null ; do
              sleep 5;
          done' && ssh -o 'StrictHostKeyChecking no' \
                 -o 'ConnectionAttempts 5' \
                 -i private.key  ubuntu@${aws_eip.vault_ip.public_ip} \
                  timeout ${var.connection_timeout}s bash -c '
          while [ ! -e ${var.vault_local_mount_path}/vault/kes_role_id ] ; do
              sleep 5;
          done' && ssh -o "StrictHostKeyChecking no" \
                       -o "ConnectionAttempts 5" \
                       -i private.key \
                       ubuntu@${aws_eip.vault_ip.public_ip} \
                       cat ${var.vault_local_mount_path}/vault/kes_role_id
          '
  EOT
  depends_on = [null_resource.vault_init]
}

module "kes_secret_id" {
  source     = "github.com/matti/terraform-shell-outputs.git"
  command    = <<EOT
          timeout ${var.connection_timeout}s bash -c '
          while ! nc -w 2 ${aws_eip.vault_ip.public_ip} 22 > /dev/null ; do
              sleep 5;
          done' && ssh -o 'StrictHostKeyChecking no' \
                 -o 'ConnectionAttempts 5' \
                 -i private.key  ubuntu@${aws_eip.vault_ip.public_ip} \
                  timeout ${var.connection_timeout}s bash -c '
          while [ ! -e ${var.vault_local_mount_path}/vault/kes_secret_id ] ; do
              sleep 5;
          done' && ssh -o "StrictHostKeyChecking no" \
                       -o "ConnectionAttempts 5" \
                       -i private.key \
                       ubuntu@${aws_eip.vault_ip.public_ip} \
                       cat ${var.vault_local_mount_path}/vault/kes_secret_id
          '
  EOT
  depends_on = [null_resource.vault_init]
}
