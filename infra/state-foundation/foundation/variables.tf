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

# ECR pull-through cache rules for public base images (GA-#511). Defaults in the
# registries module to a single Docker Hub rule (the only upstream our builds
# use); override per-account here if a stack needs extra upstreams.
variable "ecr_pull_through_cache_rules" {
  description = "Per-account override for the registries module's ECR pull-through cache rules. See modules/registries/variables.tf for the shape and Docker Hub default."
  type = map(object({
    ecr_repository_prefix = string
    upstream_registry_url = string
    authenticated         = bool
  }))
  default = {
    dockerhub = {
      ecr_repository_prefix = "docker-hub"
      upstream_registry_url = "registry-1.docker.io"
      authenticated         = true
    }
  }
}

variable "tags" {
  description = "Extra tags merged into every resource."
  type        = map(string)
  default     = {}
}

# --- Observability (CZID-364) -------------------------------------------------
variable "enable_container_insights" {
  description = <<-EOT
    Enable the amazon-cloudwatch-observability EKS addon (Container Insights) in
    the foundation eks module. Publishes node/pod metrics that the EKS baseline
    alarms depend on. Opt-in per env (per-node CloudWatch cost; only reconciles
    once nodes are Ready) — apply deliberately (Bucket B).
  EOT
  type        = bool
  default     = false
}

variable "enable_eks_alarms" {
  description = <<-EOT
    Create the baseline EKS CloudWatch alarms (node NotReady / low node count /
    pods failed / node CPU+memory in monitoring-eks.tf, plus the control-plane
    apiserver-5xx alarm in monitoring-eks-controlplane.tf). The node/pod alarms
    require enable_container_insights so the ContainerInsights metrics exist; the
    control-plane 5xx alarm only needs cluster audit logging (already enabled).
    Keep false until the cluster (+ addon, for the node/pod alarms) is live.
  EOT
  type        = bool
  default     = false
}

variable "eks_apiserver_5xx_threshold" {
  description = <<-EOT
    Sum of apiserver 5xx audit entries over the alarm period (5m) above which the
    EKS control-plane 5xx alarm fires. Conservative default; tune once a real
    baseline is observed. Only used when enable_eks_alarms = true.
  EOT
  type        = number
  default     = 10
}
