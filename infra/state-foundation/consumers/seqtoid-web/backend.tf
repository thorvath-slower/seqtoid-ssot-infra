# state-foundation/consumers/seqtoid-web/backend.tf
# -----------------------------------------------------------------------------
# A DOWNSTREAM stack (this pattern is copied into each repo's terraform/).
# Same shared bucket, its OWN unique key — never shares a state object with
# another stack.
#
#   terraform init -backend-config=../../backend.hcl   # path to the shared backend.hcl
# -----------------------------------------------------------------------------
terraform {
  required_version = ">= 1.6"
  backend "s3" {
    key = "apps/seqtoid-web/terraform.tfstate"
  }
}
