resource "tls_private_key" "main" {
  algorithm = "RSA"
}

resource "null_resource" "main" {
  provisioner "local-exec" {
    command = "echo \"${tls_private_key.main.private_key_pem}\" > private.key && echo \"${tls_private_key.main.public_key_openssh}\" > public.key"
  }

  provisioner "local-exec" {
    command = "chmod 600 private.key"
  }
}
