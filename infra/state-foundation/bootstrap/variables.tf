# state-foundation/bootstrap/variables.tf
variable "region" {
  description = "AWS region that hosts the shared state bucket and lock table."
  type        = string
  default     = "us-west-2"
}

variable "state_backup_retention_days" {
  description = "How long to keep prior (noncurrent) state versions as backups."
  type        = number
  default     = 90
}
