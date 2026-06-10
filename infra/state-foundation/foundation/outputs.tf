# state-foundation/foundation/outputs.tf
# -----------------------------------------------------------------------------
# THE INHERITANCE CONTRACT.
# These outputs are the ONLY things downstream stacks can read from the
# foundation (terraform_remote_state exposes outputs, not raw resources).
# Treat this file as a stable API: add freely, change/remove with care.
#
# Wire the right-hand side to the foundation stack's actual resource/module
# addresses (placeholders shown so the shape is clear).
# -----------------------------------------------------------------------------

# --- Networking --------------------------------------------------------------
output "vpc_id" {
  value = module.network.vpc_id
}
output "private_subnet_ids" {
  value = module.network.private_subnet_ids
}
output "public_subnet_ids" {
  value = module.network.public_subnet_ids
}

# --- EKS ---------------------------------------------------------------------
output "eks_cluster_name" {
  value = module.eks.cluster_name
}
output "eks_cluster_endpoint" {
  value = module.eks.cluster_endpoint
}
output "eks_oidc_provider_arn" {
  value = module.eks.oidc_provider_arn
}

# --- Identity / security -----------------------------------------------------
output "shared_iam_role_arns" {
  value = { for k, r in aws_iam_role.shared : k => r.arn }
}
output "kms_key_arn" {
  value = aws_kms_key.app.arn
}
output "openbao_address" {
  value = module.openbao.address
}

# --- Registries / data -------------------------------------------------------
output "ecr_registry_url" {
  value = module.registries.ecr_url
}
output "codeartifact_endpoint" {
  value = module.registries.codeartifact_endpoint
}
