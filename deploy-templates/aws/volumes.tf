resource "aws_ebs_volume" "vault_ebs" {
  availability_zone = var.aws_zone
  iops              = var.ebs_iops
  size              = var.ebs_size
  throughput        = var.ebs_throughput
  type              = var.ebs_type

  tags = {
    Name = "vault-${var.cluster_name}"
  }
}
resource "aws_volume_attachment" "vault_ebs" {
  device_name                    = var.vault_volume_mount_path
  volume_id                      = aws_ebs_volume.vault_ebs.id
  instance_id                    = aws_instance.vault.id
  stop_instance_before_detaching = true
}