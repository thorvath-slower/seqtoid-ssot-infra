# foundation/modules/openbao/outputs.tf
output "address" {
  description = "Stable OpenBao address consumers read from the foundation."
  value       = local.address
}

output "unseal_kms_key_arn" {
  description = "KMS key ARN OpenBao uses for AWS-KMS auto-unseal."
  value       = aws_kms_key.unseal.arn
}

output "unseal_role_arn" {
  description = "IRSA role ARN the OpenBao pod assumes for auto-unseal."
  value       = aws_iam_role.unseal.arn
}
