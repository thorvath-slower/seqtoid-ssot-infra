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

# --- Disaster recovery (cross-region replication) ----------------------------
variable "enable_dr" {
  description = "Replicate state to a second-region bucket for region-loss DR. Off by default."
  type        = bool
  default     = false
}

variable "dr_region" {
  description = "Destination region for state replication (used only when enable_dr = true)."
  type        = string
  default     = "us-east-1"
}
