# foundation/modules/registries/variables.tf
variable "name" {
  description = "Name prefix / ECR namespace (e.g. czid-prod)."
  type        = string
}

variable "kms_key_arn" {
  description = "KMS key ARN used to encrypt ECR and CodeArtifact."
  type        = string
}

variable "ecr_repositories" {
  description = "Service image repos to create (each becomes <name>/<repo>)."
  type        = list(string)
  default     = ["seqtoid-web", "graphql-federation", "seqtoid-workflows"]
}

variable "pull_through_cache_rules" {
  description = <<-EOT
    ECR pull-through cache rules that proxy public base-image registries into
    this account's ECR (GA-#511). Keyed by a short id; each value:
      - ecr_repository_prefix : local ECR namespace the mirror lands under
                                (images become <ecr_host>/<prefix>/<upstream-path>).
      - upstream_registry_url : the public registry to proxy (e.g.
                                registry-1.docker.io for Docker Hub).
      - authenticated         : true for registries that require login (Docker
                                Hub). true => a Secrets Manager secret is created
                                for the credential and referenced by the rule.
    Default covers Docker Hub, the only upstream our Dockerfiles / compose files
    pull from today (ruby, node, mysql, redis, nginx, opensearch*, etc.).
  EOT
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

variable "codeartifact_domain" {
  description = "CodeArtifact domain name."
  type        = string
  default     = "czid"
}

variable "codeartifact_internal_repo" {
  description = "Internal CodeArtifact repo builds resolve against."
  type        = string
  default     = "czid-internal"
}

variable "package_ecosystems" {
  description = "Public ecosystems to proxy: map of ecosystem => CodeArtifact external connection name."
  type        = map(string)
  default = {
    npm   = "public:npmjs"
    pypi  = "public:pypi"
    maven = "public:maven-central"
  }
}

variable "tags" {
  description = "Common tags."
  type        = map(string)
  default     = {}
}
