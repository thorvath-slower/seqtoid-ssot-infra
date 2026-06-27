output "bastion_instance_id" {
  description = "SSM-managed bastion instance id. Connect: aws ssm start-session --target <id>"
  value       = aws_instance.bastion.id
}

output "bastion_security_group_id" {
  description = "The bastion's (egress-only) security group id."
  value       = aws_security_group.bastion.id
}
