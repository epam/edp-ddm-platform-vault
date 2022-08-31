data "aws_route53_zone" "root_zone" {
  name         = var.baseDomain
  private_zone = false
}

resource "aws_route53_record" "vault" {
  zone_id = data.aws_route53_zone.root_zone.zone_id
  name    = "platform-vault-${var.cluster_name}.${data.aws_route53_zone.root_zone.name}"
  type    = "A"
  ttl     = "300"
  records = [aws_eip.vault_ip.public_ip]
}

