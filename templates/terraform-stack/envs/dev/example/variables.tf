variable "environment" {
  description = "Deployment environment (dev | staging | prod | support)."
  type        = string
  default     = "dev"
}

variable "region" {
  description = "AWS region for this stack."
  type        = string
  default     = "us-west-2"
}
