resource "tls_private_key" "main" {
  algorithm = "RSA"
}

resource "null_resource" "main" {
  provisioner "local-exec" {
    command = "echo \"${tls_private_key.main.private_key_pem}\" > private.key"
  }

  provisioner "local-exec" {
    command = "chmod 600 private.key"
  }
}

resource "aws_key_pair" "main" {
  key_name   = "vault-kms-unseal-${var.cluster_name}"
  public_key = tls_private_key.main.public_key_openssh
}
