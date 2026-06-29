# state-foundation/foundation/backend.tf
# -----------------------------------------------------------------------------
# The MASTER / foundation state. Holds shared, long-lived infrastructure that
# every other stack depends on, and publishes it via outputs (see outputs.tf).
#
#   terraform init -backend-config=../backend.hcl
# -----------------------------------------------------------------------------
terraform {
  required_version = ">= 1.6"
  backend "s3" {
    key = "foundation/terraform.tfstate"
    # bucket / region / dynamodb_table / kms_key_id / encrypt come from backend.hcl
    # Terraform >= 1.10 alternative to DynamoDB:
    # use_lockfile = true
  }
}
