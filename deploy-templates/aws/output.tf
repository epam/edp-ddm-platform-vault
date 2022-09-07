output "connections" {
  value = <<VAULT
Connect to Vault via SSH ssh ubuntu@${aws_eip.vault_ip.public_ip} -i private.key
Vault web interface  https://${aws_route53_record.vault.name}:8200/ui
VAULT
}

output "vault_root_token" {
  value = module.files.stdout
}