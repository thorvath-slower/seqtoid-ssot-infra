# state-foundation/backend.hcl
# -----------------------------------------------------------------------------
# SHARED partial backend config. Every stack passes this at init and adds only
# its own unique `key`:
#
#   terraform init -backend-config=../state-foundation/backend.hcl
#
# Populate these from `terraform output backend_hcl` in bootstrap/.
# -----------------------------------------------------------------------------
bucket         = "czid-tfstate-<ACCOUNT_ID>-us-west-2"
region         = "us-west-2"
dynamodb_table = "czid-tfstate-locks"   # or remove and set use_lockfile = true (Terraform >= 1.10)
kms_key_id     = "arn:aws:kms:us-west-2:<ACCOUNT_ID>:key/<KEY_ID>"
encrypt        = true
