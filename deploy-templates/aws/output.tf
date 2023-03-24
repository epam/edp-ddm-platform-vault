output "connections" {
  value = <<VAULT
Connect to Vault via SSH ssh ubuntu@${aws_eip.vault_ip.public_ip} -i private.key
Vault web interface  http://${aws_eip.vault_ip.public_ip}:8200/ui
VAULT
}

output "vault_root_token" {
  value = module.files.stdout
}

output "vault_elastic_ip" {
  value = aws_eip.vault_ip.public_ip
}
