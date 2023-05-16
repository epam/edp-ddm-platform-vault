output "vault_root_token" {
  sensitive = true
  value     = module.files.stdout
}
