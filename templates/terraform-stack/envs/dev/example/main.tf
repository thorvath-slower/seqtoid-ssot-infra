# Example stack contents. Replace with your real resources.
#
# `terraform_data` is a built-in no-op resource — it lets this template validate
# and `init -backend=false` cleanly with no cloud calls. Delete it once you add
# real resources.
resource "terraform_data" "example" {
  input = "${var.environment}-${var.region}"
}

# --- Example AWS resource (uncomment + adapt) -------------------------------
# resource "aws_s3_bucket" "example" {
#   bucket = "czid-${var.environment}-example"
# }
#
# resource "aws_s3_bucket_public_access_block" "example" {
#   bucket                  = aws_s3_bucket.example.id
#   block_public_acls       = true
#   block_public_policy     = true
#   ignore_public_acls      = true
#   restrict_public_buckets = true
# }
# ---------------------------------------------------------------------------

output "example_id" {
  description = "Demonstrates a stack output."
  value       = terraform_data.example.output
}
