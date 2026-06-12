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
