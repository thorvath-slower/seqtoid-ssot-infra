# foundation/modules/openbao/variables.tf
variable "name" {
  description = "Name prefix (e.g. czid-prod)."
  type        = string
}

variable "oidc_provider_arn" {
  description = "EKS IRSA OIDC provider ARN (from the eks module)."
  type        = string
}

variable "oidc_provider_url" {
  description = "EKS OIDC issuer URL, host form (no scheme)."
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace OpenBao runs in."
  type        = string
  default     = "openbao"
}

variable "service_account" {
  description = "OpenBao service account name (IRSA subject)."
  type        = string
  default     = "openbao"
}

variable "service_name" {
  description = "OpenBao in-cluster Service name (used to build the address)."
  type        = string
  default     = "openbao"
}

variable "address_override" {
  description = "Override the published address (e.g. a stable ingress hostname). Empty = in-cluster service DNS."
  type        = string
  default     = null
}

variable "tags" {
  description = "Common tags."
  type        = map(string)
  default     = {}
}
