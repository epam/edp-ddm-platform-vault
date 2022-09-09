resource "aws_eip" "vault_ip" {
  vpc = true
}

resource "aws_eip_association" "vault_public" {
  instance_id   = aws_instance.vault.id
  allocation_id = aws_eip.vault_ip.id
}