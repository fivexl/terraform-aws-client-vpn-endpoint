# A Client VPN endpoint supports 1024-bit and 2048-bit RSA key sizes only.
resource "tls_private_key" "this" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "this" {
  key_algorithm   = tls_private_key.this.algorithm
  private_key_pem = tls_private_key.this.private_key_pem
  subject {
    common_name = var.tls_subject_common_name
  }
  validity_period_hours = var.tls_validity_period_hours
  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
    "ipsec_end_system",
    "ipsec_tunnel",
    "any_extended",
    "cert_signing"
  ]
}

resource "aws_acm_certificate" "this" {
  private_key      = tls_private_key.this.private_key_pem
  certificate_body = tls_self_signed_cert.this.cert_pem
  tags = merge(
    {
      Name = var.tls_subject_common_name
    },
    var.tags,
  )
}

data "aws_vpc" "this" {
  id = var.endpoint_vpc_id
}

resource "aws_cloudwatch_log_group" "this" {
  name              = "${var.cloudwatch_log_group_name_prefix}${var.endpoint_name}"
  retention_in_days = var.cloudwatch_log_group_retention_in_days
  tags              = var.tags
}

resource "aws_cloudwatch_log_stream" "this" {
  log_group_name = aws_cloudwatch_log_group.this.name
  name           = "connection-log"
}

resource "aws_ec2_client_vpn_endpoint" "this_sso" {
  description            = var.endpoint_name
  server_certificate_arn = aws_acm_certificate.this.arn
  client_cidr_block      = var.endpoint_client_cidr_block
  split_tunnel           = var.enable_split_tunnel
  transport_protocol     = var.transport_protocol
  dns_servers            = var.use_vpc_internal_dns ? [cidrhost(data.aws_vpc.this.cidr_block, 2)] : var.dns_servers
  authentication_options {
    type              = "federated-authentication"
    saml_provider_arn = var.saml_provider_arn
  }
  connection_log_options {
    enabled               = true
    cloudwatch_log_group  = aws_cloudwatch_log_group.this.name
    cloudwatch_log_stream = aws_cloudwatch_log_stream.this.name
  }
  tags = merge(
    {
      Name = var.endpoint_name
    },
    var.tags,
  )
}

resource "aws_security_group" "this" {
  name        = "client-vpn-endpoint-${var.endpoint_name}"
  description = "Egress All. Used for other groups where VPN access is required. "
  vpc_id      = var.endpoint_vpc_id
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = var.tags
}

resource "aws_ec2_client_vpn_network_association" "this_sso" {
  for_each               = toset(var.endpoint_subnets)
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.this_sso.id
  subnet_id              = each.value
  security_groups        = [aws_security_group.this.id]
}

resource "aws_ec2_client_vpn_authorization_rule" "this_sso_to_dns" {
  count                  = var.use_vpc_internal_dns ? 1 : 0
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.this_sso.id
  target_network_cidr    = "${cidrhost(data.aws_vpc.this.cidr_block, 2)}/32"
  authorize_all_groups   = true
  description            = "Authorization for ${var.endpoint_name} to DNS"
}

resource "aws_ec2_client_vpn_authorization_rule" "this" {
  for_each               = var.authorization_rules
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.this_sso.id
  target_network_cidr    = split(",", each.value)[0]
  access_group_id        = split(",", each.value)[1]
  description            = "Rule name: ${each.key}"
}

resource "aws_ec2_client_vpn_authorization_rule" "this_all_groups" {
  for_each               = var.authorization_rules_all_groups
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.this_sso.id
  target_network_cidr    = each.value
  authorize_all_groups   = true
  description            = "Rule name: ${each.key}"
}

resource "aws_ec2_client_vpn_route" "this_sso" {
  for_each               = var.additional_routes
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.this_sso.id
  destination_cidr_block = each.value
  target_vpc_subnet_id   = aws_ec2_client_vpn_network_association.this_sso[each.key].subnet_id
  description            = "From ${each.key} to ${each.value}"
}
