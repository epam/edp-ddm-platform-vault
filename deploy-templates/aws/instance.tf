resource "aws_kms_key" "vault" {
  description             = "Vault unseal key"
  deletion_window_in_days = 10

  tags = local.tags
}

resource "aws_instance" "vault" {

  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public_subnet.id
  key_name      = "vault-kms-unseal-${var.cluster_name}"
  monitoring    = "false"

  vpc_security_group_ids = [
    aws_security_group.vault.id,
    aws_security_group.custom.id,
  ]

  ebs_optimized        = false
  iam_instance_profile = aws_iam_instance_profile.vault-kms-unseal.id

  tags = local.tags

  user_data = data.template_file.vault.rendered

}

resource "aws_security_group" "custom" {
  name        = "vault-kms-unseal-${var.cluster_name}-custom"
  description = "Custom vault access"
  vpc_id      = aws_vpc.vpc.id

  tags = local.tags

  # SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.custom_ingress_rules_cidrs
  }

  # Vault Client Traffic
  ingress {
    from_port   = 8200
    to_port     = 8200
    protocol    = "tcp"
    cidr_blocks = var.custom_ingress_rules_cidrs
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.custom_ingress_rules_cidrs
  }

}

resource "aws_security_group" "vault" {
  name        = "vault-kms-unseal-${var.cluster_name}"
  description = "vault access"
  vpc_id      = aws_vpc.vpc.id

  tags = local.tags

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
    cidr_blocks = ["${chomp(data.http.external_ip.body)}/32"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${chomp(data.http.external_ip.body)}/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "null_resource" "user_data_status_check" {

  provisioner "local-exec" {
    on_failure  = fail
    interpreter = ["/bin/bash", "-c"]
    command     = <<EOT
          echo -e "\x1B[31m wait for few minute for instance warm up, adjust accordingly \x1B[0m"
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
      ENDPOINT = "https://${aws_route53_record.vault.name}:8200/"
    }
  }
  depends_on = [null_resource.user_data_status_check]
}

resource "null_resource" "backup_and_migrate_vault_data" {
  count = var.enable-vault_data-migration_to_ebs ? 1 : 0

  provisioner "remote-exec" {
    inline = [data.template_file.backup_and_migrate_data.rendered]

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

module "files" {
  source     = "github.com/matti/terraform-shell-outputs.git"
  command    = "timeout ${var.connection_timeout}s bash -c 'while ! nc -w 2 ${aws_eip.vault_ip.public_ip} 22 > /dev/null ; do echo \"Waiting for SSH port open\" > /dev/null; sleep 5; done' && ssh -o \"StrictHostKeyChecking no\" -o 'ConnectionAttempts 5' ubuntu@${aws_eip.vault_ip.public_ip} -i private.key cat ${var.vault_local_mount_path}/vault/keys | grep Root | awk -F : {'print $2'} | cut -c2-"
  depends_on = [null_resource.vault_init]
}

