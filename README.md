# terraform-aws-client-vpn-endpoint
AWS Client VPN endpoint

## Info
- [AWS Client VPN pricing](https://aws.amazon.com/vpn/pricing/)

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
  name                   = var.vpn_saml_provider_name
  saml_metadata_document = base64decode(jsondecode(data.aws_secretsmanager_secret_version.saml.secret_string)["saml_metadata_xml"]) # saml_metadata_xml
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