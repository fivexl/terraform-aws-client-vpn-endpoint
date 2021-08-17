# terraform-aws-client-vpn-endpoint
AWS Client VPN endpoint

## Info
- [AWS Client VPN pricing](https://aws.amazon.com/vpn/pricing/)

## How to create Application for VPN in AWS Single Sign-On
- Open AWS SSO service page. Select Applications from the sidebar
- Choose Add a new application
- Select Add a custom SAML 2.0 application
- Fill Display name and Description
- Set session duration (VPN session duration) - 12h
- Select "If you don't have a metadata file, you can manually type your metadata values."
- Application ACS URL: http://127.0.0.1:35001
- Application SAML audience: urn:amazon:webservices:clientvpn
- Save changes
- Download AWS SSO SAML metadata file (file for vpn secret)
- Select tab "Attribute mappings":
    - Subject -> ${user:subject} -> emailAddress
    - NameID -> ${user:email} -> basic
    - memberOf -> ${user:groups} -> unspecified
- Select tab "Assigned users"
- Assign users or groups created on previous step

## Example

```hcl 

# Get metadata.xml file from AWS SSO/Applications
# Encode file with base64 `base64 -w 0` (linux only) or `openssl base64 -A`
# Create secret `saml_metadata` with key `saml_metadata_xml` and value base64

data "aws_secretsmanager_secret" "saml" {
  name = "saml_metadata"
}

data "aws_secretsmanager_secret_version" "saml" {
  secret_id     = data.aws_secretsmanager_secret.saml.id
  version_stage = "AWSCURRENT"
}

resource "aws_iam_saml_provider" "vpn" {
  name                   = var.vpn_saml_provider_name # could be anything that satisfy regular expression pattern: [\w._-]+ 
  saml_metadata_document = base64decode(jsondecode(data.aws_secretsmanager_secret_version.saml.secret_string)["saml_metadata_xml"]) # saml_metadata_xml
  tags                   = var.tags
}

module "vpn" {
  source                     = "fivexl/client-vpn-endpoint/aws"
  endpoint_name              = "myvpn"
  endpoint_client_cidr_block = "10.100.0.0/16"
  endpoint_subnets           = [module.vpc.intra_subnets[0]] # Attach VPN to single subnet. Reduce cost
  endpoint_vpc_id            = module.vpc.vpc_id
  tls_subject_common_name    = "int.example.com"
  saml_provider_arn          = aws_iam_saml_provider.vpn.arn

  authorization_rules = {}

  authorization_rules_all_groups = {
    full_access_private_subnet_0 = module.vpc.private_subnets_cidr_blocks[0]
  }

  tags = var.tags
}
```

## Example with VPC module
```hcl
variable "vpn_access_public" {
  description = "List of SSO Group IDs for accessing public subnets"
  type        = list(string)
  default     = []
}

variable "vpn_access_private" {
  description = "List of SSO Group IDs for accessing private subnets"
  type        = list(string)
  default     = []
}

variable "vpn_access_intra" {
  description = "List of SSO Group IDs for accessing intra subnets"
  type        = list(string)
  default     = []
}

variable "vpn_access_db" {
  description = "List of SSO Group IDs for accessing db subnets"
  type        = list(string)
  default     = []
}

variable "vpn_access_elasticache" {
  description = "List of SSO Group IDs for accessing elasticache subnets"
  type        = list(string)
  default     = []
}

variable "vpn_access_all" {
  description = "List of SSO Group IDs for accessing all subnets"
  type        = list(string)
  default     = []
}

# https://docs.aws.amazon.com/vpn/latest/clientvpn-admin/limits.html
# Authorization rules per Client VPN endpoint defaul quota is 50
# https://console.aws.amazon.com/servicequotas/home/services/ec2/quotas/L-9A1BC94B
locals {
  vpn_authorization_rules_public      = { for item in setproduct(module.vpc.public_subnets_cidr_blocks, var.vpn_access_public) : "public_${item[0]}_${item[1]}" => "${item[0]},${item[1]}" }
  vpn_authorization_rules_private     = { for item in setproduct(module.vpc.private_subnets_cidr_blocks, var.vpn_access_private) : "private_${item[0]}_${item[1]}" => "${item[0]},${item[1]}" }
  vpn_authorization_rules_intra       = { for item in setproduct(module.vpc.intra_subnets_cidr_blocks, var.vpn_access_intra) : "intra_${item[0]}_${item[1]}" => "${item[0]},${item[1]}" }
  vpn_authorization_rules_db          = { for item in setproduct(module.vpc.database_subnets_cidr_blocks, var.vpn_access_db) : "db_${item[0]}_${item[1]}" => "${item[0]},${item[1]}" }
  vpn_authorization_rules_elasticache = { for item in setproduct(module.vpc.elasticache_subnets_cidr_blocks, var.vpn_access_elasticache) : "elasticache_${item[0]}_${item[1]}" => "${item[0]},${item[1]}" }
  vpn_authorization_rules_all         = { for item in setproduct([module.vpc.vpc_cidr_block], var.vpn_access_all) : "all_${item[0]}_${item[1]}" => "${item[0]},${item[1]}" }
  vpn_authorization_rules = merge(
    local.vpn_authorization_rules_public,
    local.vpn_authorization_rules_private,
    local.vpn_authorization_rules_intra,
    local.vpn_authorization_rules_db,
    local.vpn_authorization_rules_elasticache,
    local.vpn_authorization_rules_all
  )
}

module "vpn" {
  source                     = "fivexl/client-vpn-endpoint/aws"
  endpoint_name              = "myvpn"
  endpoint_client_cidr_block = "10.100.0.0/16"
  endpoint_subnets           = [module.vpc.intra_subnets[0]] # Attach VPN to single subnet. Reduce cost
  endpoint_vpc_id            = module.vpc.vpc_id
  tls_subject_common_name    = "int.example.com"
  saml_provider_arn          = data.aws_ssm_parameter.iam_vpn_saml_provider_arn.value

  authorization_rules = local.vpn_authorization_rules

  authorization_rules_all_groups = {}

  tags = var.tags
}
```

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 0.15 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 3.33 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 3.33 |
| <a name="provider_tls"></a> [tls](#provider\_tls) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_acm_certificate.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate) | resource |
| [aws_cloudwatch_log_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_stream.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_stream) | resource |
| [aws_ec2_client_vpn_authorization_rule.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_client_vpn_authorization_rule) | resource |
| [aws_ec2_client_vpn_authorization_rule.this_all_groups](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_client_vpn_authorization_rule) | resource |
| [aws_ec2_client_vpn_authorization_rule.this_sso_to_dns](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_client_vpn_authorization_rule) | resource |
| [aws_ec2_client_vpn_endpoint.this_sso](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_client_vpn_endpoint) | resource |
| [aws_ec2_client_vpn_network_association.this_sso](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_client_vpn_network_association) | resource |
| [aws_security_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [tls_private_key.this](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/private_key) | resource |
| [tls_self_signed_cert.this](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/self_signed_cert) | resource |
| [aws_vpc.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/vpc) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_authorization_rules"></a> [authorization\_rules](#input\_authorization\_rules) | Map containing authorization rule configuration. rule\_name = "target\_network\_cidr, access\_group\_id" . | `map(string)` | `{}` | no |
| <a name="input_authorization_rules_all_groups"></a> [authorization\_rules\_all\_groups](#input\_authorization\_rules\_all\_groups) | Map containing authorization rule configuration with authorize\_all\_groups=true. rule\_name = "target\_network\_cidr" . | `map(string)` | `{}` | no |
| <a name="input_cloudwatch_log_group_name_prefix"></a> [cloudwatch\_log\_group\_name\_prefix](#input\_cloudwatch\_log\_group\_name\_prefix) | Specifies the name prefix of CloudWatch Log Group for VPC flow logs. | `string` | `"/aws/client-vpn-endpoint/"` | no |
| <a name="input_cloudwatch_log_group_retention_in_days"></a> [cloudwatch\_log\_group\_retention\_in\_days](#input\_cloudwatch\_log\_group\_retention\_in\_days) | Specifies the number of days you want to retain log events in the specified log group for VPN connection logs. | `number` | `30` | no |
| <a name="input_endpoint_client_cidr_block"></a> [endpoint\_client\_cidr\_block](#input\_endpoint\_client\_cidr\_block) | The IPv4 address range, in CIDR notation, from which to assign client IP addresses. The address range cannot overlap with the local CIDR of the VPC in which the associated subnet is located, or the routes that you add manually. The address range cannot be changed after the Client VPN endpoint has been created. The CIDR block should be /22 or greater. | `string` | `"10.100.100.0/24"` | no |
| <a name="input_endpoint_name"></a> [endpoint\_name](#input\_endpoint\_name) | Name to be used on the Client VPN Endpoint | `string` | n/a | yes |
| <a name="input_endpoint_subnets"></a> [endpoint\_subnets](#input\_endpoint\_subnets) | List of IDs of endpoint subnets for network association | `list(string)` | n/a | yes |
| <a name="input_endpoint_vpc_id"></a> [endpoint\_vpc\_id](#input\_endpoint\_vpc\_id) | VPC where the VPN will be connected. | `string` | n/a | yes |
| <a name="input_saml_provider_arn"></a> [saml\_provider\_arn](#input\_saml\_provider\_arn) | The ARN of the IAM SAML identity provider. | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | A map of tags to add to all resources | `map(string)` | `{}` | no |
| <a name="input_tls_subject_common_name"></a> [tls\_subject\_common\_name](#input\_tls\_subject\_common\_name) | The common\_name for subject for which a certificate is being requested. RFC5280. | `string` | n/a | yes |
| <a name="input_tls_validity_period_hours"></a> [tls\_validity\_period\_hours](#input\_tls\_validity\_period\_hours) | Specifies the number of hours after initial issuing that the certificate will become invalid. | `number` | `47400` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_security_group_description"></a> [security\_group\_description](#output\_security\_group\_description) | n/a |
| <a name="output_security_group_id"></a> [security\_group\_id](#output\_security\_group\_id) | n/a |
| <a name="output_security_group_name"></a> [security\_group\_name](#output\_security\_group\_name) | n/a |
| <a name="output_security_group_vpc_id"></a> [security\_group\_vpc\_id](#output\_security\_group\_vpc\_id) | n/a |
