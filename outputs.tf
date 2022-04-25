output "security_group_id" {
  description = "A map of tags to add to all resources"
  value       = aws_security_group.this.id
}

output "security_group_name" {
  description = "Name of the security group"
  value       = aws_security_group.this.name
}

output "security_group_description" {
  description = "Security group description"
  value       = aws_security_group.this.description
}

output "security_group_vpc_id" {
  description = "VPC ID"
  value       = aws_security_group.this.vpc_id
}

output "ec2_client_vpn_endpoint_id" {
  description = "The ID of the Client VPN endpoint"
  value       = aws_ec2_client_vpn_endpoint.this_sso.id
}

output "ec2_client_vpn_endpoint_arn" {
  description = "The ARN of the Client VPN endpoint"
  value       = aws_ec2_client_vpn_endpoint.this_sso.arn
}

output "ec2_client_vpn_network_associations" {
  description = "Network associations for AWS Client VPN endpoint"
  value       = aws_ec2_client_vpn_network_association.this_sso
}