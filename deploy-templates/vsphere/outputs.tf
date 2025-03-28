output "vault_root_token" {
  sensitive = true
  value     = module.files.stdout
}

output "vault_auth_kes_role_id" {
  sensitive = true
  value = module.kes_role_id.stdout
}

output "vault_auth_kes_secret_id" {
  sensitive = true
  value = module.kes_secret_id.stdout
}