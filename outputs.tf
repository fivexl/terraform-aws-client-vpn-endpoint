output "security_group_id" {
  value = aws_security_group.this.id
}

output "security_group_name" {
  value = aws_security_group.this.name
}

output "security_group_description" {
  value = aws_security_group.this.description
}

output "security_group_vpc_id" {
  value = aws_security_group.this.vpc_id
}

output "ec2_client_vpn_endpoint_id" {
  value = aws_ec2_client_vpn_endpoint.this_sso.id
}

output "ec2_client_vpn_endpoint_arn" {
  value = aws_ec2_client_vpn_endpoint.this_sso.arn
}