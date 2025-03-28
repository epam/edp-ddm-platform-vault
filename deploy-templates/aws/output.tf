output "connections" {
  value = <<VAULT
Connect to Vault via SSH ssh ubuntu@${aws_eip.vault_ip.public_ip} -i private.key
Vault web interface  http://${aws_eip.vault_ip.public_ip}:8200/ui
VAULT
}

output "vault_root_token" {
  sensitive = true
  value     = module.root_token.stdout
}

output "vault_kes_role_id" {
  sensitive = true
  value     = module.kes_role_id.stdout
}

output "vault_kes_secret_id" {
  sensitive = true
  value     = module.kes_secret_id.stdout
}

output "vault_elastic_ip" {
  value = aws_eip.vault_ip.public_ip
}

output "vault_private_ip" {
  value = aws_instance.vault.private_ip
}