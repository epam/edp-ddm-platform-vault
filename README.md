<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 0.12 |
| <a name="requirement_keycloak"></a> [keycloak](#requirement\_keycloak) | >= 2.0.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 4.24.0 |
| <a name="provider_http"></a> [http](#provider\_http) | 3.0.1 |
| <a name="provider_null"></a> [null](#provider\_null) | 3.1.1 |
| <a name="provider_template"></a> [template](#provider\_template) | 2.2.0 |
| <a name="provider_tls"></a> [tls](#provider\_tls) | 4.0.1 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_files"></a> [files](#module\_files) | github.com/matti/terraform-shell-outputs.git | n/a |

## Resources

| Name | Type |
|------|------|
| [aws_ebs_volume.vault_ebs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ebs_volume) | resource |
| [aws_eip.vault_ip](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eip) | resource |
| [aws_eip_association.vault_public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eip_association) | resource |
| [aws_iam_instance_profile.vault-kms-unseal](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_instance_profile) | resource |
| [aws_iam_role.vault-kms-unseal](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.vault-kms-unseal](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_instance.vault](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance) | resource |
| [aws_internet_gateway.gw](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/internet_gateway) | resource |
| [aws_key_pair.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/key_pair) | resource |
| [aws_kms_key.vault](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key) | resource |
| [aws_route_table.route](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table) | resource |
| [aws_route_table_association.route](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |
| [aws_security_group.vault](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_subnet.public_subnet](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [aws_volume_attachment.vault_ebs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/volume_attachment) | resource |
| [aws_vpc.vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc) | resource |
| [null_resource.backup_and_migrate_vault_data](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.main](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.user_data_status_check](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.vault_init](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [tls_private_key.main](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/private_key) | resource |
| [aws_ami.ubuntu](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ami) | data source |
| [aws_iam_policy_document.assume_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.vault-kms-unseal](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_nat_gateway.cluster_ip](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/nat_gateway) | data source |
| [aws_route53_zone.root_zone](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/route53_zone) | data source |
| [http_http.external_ip](https://registry.terraform.io/providers/hashicorp/http/latest/docs/data-sources/http) | data source |
| [template_file.backup_and_migrate_data](https://registry.terraform.io/providers/hashicorp/template/latest/docs/data-sources/file) | data source |
| [template_file.format_ssh](https://registry.terraform.io/providers/hashicorp/template/latest/docs/data-sources/file) | data source |
| [template_file.vault](https://registry.terraform.io/providers/hashicorp/template/latest/docs/data-sources/file) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | n/a | `string` | `"eu-central-1"` | no |
| <a name="input_aws_zone"></a> [aws\_zone](#input\_aws\_zone) | n/a | `string` | `"eu-central-1b"` | no |
| <a name="input_baseDomain"></a> [baseDomain](#input\_baseDomain) | baseDomain | `string` | `"mdtu-ddm.projects.epam.com"` | no |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | Cluster name | `string` | `"main"` | no |
| <a name="input_connection_timeout"></a> [connection\_timeout](#input\_connection\_timeout) | The amount of seconds while terraform will attempt to connect to the host to complete null resources. \|<br>**Optional** \| | `number` | `600` | no |
| <a name="input_ebs_iops"></a> [ebs\_iops](#input\_ebs\_iops) | The amount of IOPS to provision for the disk. \|<br>Only valid for `type` of `io1`, `io2` or `gp3`. \|<br>The details you can find [here](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ebs-volume-types.html). \|<br>**Optional** \| | `number` | `0` | no |
| <a name="input_ebs_size"></a> [ebs\_size](#input\_ebs\_size) | The size of the drive in GiBs. \|<br>**Optional** \| | `number` | `10` | no |
| <a name="input_ebs_throughput"></a> [ebs\_throughput](#input\_ebs\_throughput) | The throughput that the volume supports, in MiB/s. \|<br>Only valid for `type` of `gp3`. \|<br>The details you can find [here](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ebs-volume-types.html). \|<br>**Optional** \| | `number` | `200` | no |
| <a name="input_ebs_type"></a> [ebs\_type](#input\_ebs\_type) | The type of EBS volume. Can be standard, `gp2`, `gp3`, `io1`, `io2`, `sc1` or `st1`. \|<br>The details you can find [here](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ebs-volume-types.html). \|<br>**Optional** \| | `string` | `"gp3"` | no |
| <a name="input_enable-vault_data-migration_to_ebs"></a> [enable-vault\_data-migration\_to\_ebs](#input\_enable-vault\_data-migration\_to\_ebs) | Enable and disable remote-exec to migrate vault data to ebs volume. \|<br>**Optional** \| | `bool` | `true` | no |
| <a name="input_ssh_user"></a> [ssh\_user](#input\_ssh\_user) | The user to access server over ssh. \|<br>**Optional** \| | `string` | `"ubuntu"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | A map of tags to add to all resources. | `map(any)` | n/a | yes |
| <a name="input_vault_local_mount_path"></a> [vault\_local\_mount\_path](#input\_vault\_local\_mount\_path) | The local path to be used to mount volume. \|<br>**Optional** \| | `string` | `"/apps"` | no |
| <a name="input_vault_url"></a> [vault\_url](#input\_vault\_url) | n/a | `string` | `"https://releases.hashicorp.com/vault/1.6.0/vault_1.6.0_linux_amd64.zip"` | no |
| <a name="input_vault_volume_mount_path"></a> [vault\_volume\_mount\_path](#input\_vault\_volume\_mount\_path) | The device name to expose to the instance (for example, /dev/sdh or xvdh). \|<br>See Device Naming on [Linux Instances](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/device_naming.html#available-ec2-device-names) for more information. \|<br>**Optional** \| | `string` | `"/dev/xvdh"` | no |
| <a name="input_vpc_cidr"></a> [vpc\_cidr](#input\_vpc\_cidr) | CIDR of the VPC | `string` | `"192.168.100.0/24"` | no |
| <a name="input_wait_for_cluster_interpreter"></a> [wait\_for\_cluster\_interpreter](#input\_wait\_for\_cluster\_interpreter) | Custom local-exec command line interpreter for the command to determining if the eks cluster is healthy. | `list(string)` | <pre>[<br>  "/bin/sh",<br>  "-c"<br>]</pre> | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_connections"></a> [connections](#output\_connections) | n/a |
| <a name="output_vault_root_token"></a> [vault\_root\_token](#output\_vault\_root\_token) | n/a |
<!-- END_TF_DOCS -->

### License

The platform-vault is Open Source software released under
the [Apache 2.0 license](https://www.apache.org/licenses/LICENSE-2.0).
