# state-foundation/bootstrap/outputs.tf
output "state_bucket" {
  description = "Name of the shared state bucket — put this in backend.hcl."
  value       = aws_s3_bucket.tfstate.bucket
}

output "lock_table" {
  description = "DynamoDB lock table name (omit if using OpenTofu native S3 locking)."
  value       = aws_dynamodb_table.tflock.name
}

output "kms_key_arn" {
  description = "KMS key ARN used to encrypt state."
  value       = aws_kms_key.tfstate.arn
}

# Convenience: the exact partial-backend config every other stack should use.
output "backend_hcl" {
  description = "Paste into state-foundation/backend.hcl"
  value       = <<-EOT
    bucket         = "${aws_s3_bucket.tfstate.bucket}"
    region         = "${var.region}"
    dynamodb_table = "${aws_dynamodb_table.tflock.name}"
    kms_key_id     = "${aws_kms_key.tfstate.arn}"
    encrypt        = true
  EOT
}

# DR (only populated when enable_dr = true).
output "dr_state_bucket" {
  description = "DR replica bucket name (null when DR is disabled)."
  value       = var.enable_dr ? aws_s3_bucket.tfstate_dr[0].bucket : null
}

output "dr_kms_key_arn" {
  description = "DR-region KMS key ARN (null when DR is disabled)."
  value       = var.enable_dr ? aws_kms_key.tfstate_dr[0].arn : null
}
