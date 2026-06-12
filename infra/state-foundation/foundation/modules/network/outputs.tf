# foundation/modules/network/outputs.tf
output "vpc_id" {
  description = "Shared VPC id."
  value       = aws_vpc.this.id
}

output "vpc_cidr" {
  description = "Shared VPC CIDR."
  value       = aws_vpc.this.cidr_block
}

output "public_subnet_ids" {
  description = "Public subnet ids (ALB / NAT)."
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "Private subnet ids (workloads / EKS nodes)."
  value       = aws_subnet.private[*].id
}

output "nat_gateway_ids" {
  description = "NAT gateway ids."
  value       = aws_nat_gateway.this[*].id
}
