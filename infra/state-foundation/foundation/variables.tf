# =============================================================================
# foundation/variables.tf — inputs for the shared (cloud-edition) foundation
# =============================================================================

variable "region" {
  description = "AWS region for the foundation."
  type        = string
  default     = "us-west-2"
}

variable "name_prefix" {
  description = "Prefix for all foundation resources."
  type        = string
  default     = "czid"
}

variable "environment" {
  description = "Environment this foundation serves (dev|staging|prod). Drives naming/sizing/state key prefix."
  type        = string
  default     = "prod"
}

# --- Networking ---------------------------------------------------------------
variable "vpc_cidr" {
  description = "VPC CIDR (a /16)."
  type        = string
  default     = "10.40.0.0/16"
}

variable "az_count" {
  description = "Number of AZs to spread across."
  type        = number
  default     = 3
}

variable "single_nat_gateway" {
  description = "One shared NAT (dev) vs one per AZ (prod HA)."
  type        = bool
  default     = false
}

# --- EKS ----------------------------------------------------------------------
variable "eks_cluster_version" {
  description = "EKS control-plane Kubernetes version."
  type        = string
  default     = "1.30"
}

variable "eks_node_instance_types" {
  type    = list(string)
  default = ["m6i.large"]
}

variable "eks_node_min_size" {
  type    = number
  default = 2
}

variable "eks_node_max_size" {
  type    = number
  default = 6
}

variable "eks_node_desired_size" {
  type    = number
  default = 3
}

variable "eks_public_access_cidrs" {
  description = "CIDRs allowed to reach the public API endpoint. Tighten in prod."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# --- GitHub Actions OIDC (least-privilege deploy, no static keys) -------------
variable "github_org" {
  description = "GitHub org that owns the CZ ID repos (for the OIDC deploy-role trust)."
  type        = string
  default     = "jsims-slower"
}

variable "github_deploy_repos" {
  description = "Repos allowed to assume the deploy role via OIDC (e.g. [\"cypherid-web-infra\"])."
  type        = list(string)
  default     = ["cypherid-web-infra", "cypherid-workflow-infra"]
}

variable "github_deploy_ref" {
  description = "Git ref the deploy role is scoped to (branch protection in IAM)."
  type        = string
  default     = "refs/heads/main"
}

# --- Registries ---------------------------------------------------------------
variable "ecr_repositories" {
  type    = list(string)
  default = ["seqtoid-web", "graphql-federation", "seqtoid-workflows"]
}

variable "tags" {
  description = "Extra tags merged into every resource."
  type        = map(string)
  default     = {}
}
