resource "aws_iam_role" "vault-kms-unseal" {
  name               = "vault-kms-role-${var.cluster_name}"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
  tags = merge(local.tags, {
    "Name" = "platform-vault-${var.cluster_name}"
  })
}

resource "aws_iam_role_policy" "vault-kms-unseal" {
  name   = "Vault-KMS-Unseal-${var.cluster_name}"
  role   = aws_iam_role.vault-kms-unseal.id
  policy = data.aws_iam_policy_document.vault-kms-unseal.json
}

resource "aws_iam_instance_profile" "vault-kms-unseal" {
  name = "vault-kms-unseal-${var.cluster_name}"
  role = aws_iam_role.vault-kms-unseal.name
  tags = merge(local.tags, {
    "Name" = "platform-vault-${var.cluster_name}"
  })
}