# state-foundation/consumers/seqtoid-web/remote_state.tf
# -----------------------------------------------------------------------------
# HOW A STACK "INHERITS" FROM THE MASTER.
# Reads the foundation's published outputs read-only. seqtoid-web does NOT own
# the VPC, cluster, IAM, etc. — it consumes them from the foundation state.
# -----------------------------------------------------------------------------
data "terraform_remote_state" "foundation" {
  backend = "s3"
  config = {
    bucket = var.state_bucket # same shared bucket
    key    = "foundation/terraform.tfstate"
    region = var.region
  }
}

locals {
  # Inherited values, used like any other reference downstream.
  vpc_id           = data.terraform_remote_state.foundation.outputs.vpc_id
  private_subnets  = data.terraform_remote_state.foundation.outputs.private_subnet_ids
  eks_cluster_name = data.terraform_remote_state.foundation.outputs.eks_cluster_name
  oidc_provider    = data.terraform_remote_state.foundation.outputs.eks_oidc_provider_arn
  openbao_address  = data.terraform_remote_state.foundation.outputs.openbao_address
}

# Example use:
# resource "aws_security_group" "web" {
#   vpc_id = local.vpc_id
#   # ...
# }

variable "state_bucket" {
  type = string
}

variable "region" {
  type    = string
  default = "us-west-2"
}
