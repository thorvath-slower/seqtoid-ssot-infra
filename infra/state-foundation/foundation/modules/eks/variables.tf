# foundation/modules/eks/variables.tf
variable "name" {
  description = "EKS cluster name."
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes minor version for the control plane."
  type        = string
  default     = "1.30"
}

variable "private_subnet_ids" {
  description = "Private subnets for the control plane ENIs and node group."
  type        = list(string)
}

variable "public_subnet_ids" {
  description = "Public subnets for the control plane ENIs (mixed config)."
  type        = list(string)
}

variable "kms_key_arn" {
  description = "KMS key ARN used to envelope-encrypt Kubernetes secrets in etcd."
  type        = string
}

variable "endpoint_public_access" {
  description = "Expose the API server endpoint publicly (locked down by public_access_cidrs)."
  type        = bool
  default     = true
}

variable "public_access_cidrs" {
  description = "CIDRs allowed to reach the public API endpoint. Tighten in prod."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "node_instance_types" {
  description = "Instance types for the default managed node group."
  type        = list(string)
  default     = ["m6i.large"]
}

variable "node_min_size" {
  type    = number
  default = 2
}

variable "node_max_size" {
  type    = number
  default = 6
}

variable "node_desired_size" {
  type    = number
  default = 3
}

variable "tags" {
  description = "Common tags."
  type        = map(string)
  default     = {}
}

variable "enable_container_insights" {
  description = <<-EOT
    Enable the amazon-cloudwatch-observability EKS addon (Container Insights).
    Publishes node/pod metrics to the ContainerInsights CloudWatch namespace,
    which the foundation baseline pod/node alarms depend on. Carries per-node
    CloudWatch cost and only reconciles once the node group is Ready, so it is
    opt-in per env and applied deliberately (CZID-364, apply = Bucket B).
  EOT
  type        = bool
  default     = false
}
