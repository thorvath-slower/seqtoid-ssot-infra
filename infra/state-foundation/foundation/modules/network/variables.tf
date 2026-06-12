# foundation/modules/network/variables.tf
variable "name" {
  description = "Name prefix for network resources (e.g. czid-prod)."
  type        = string
}

variable "cidr" {
  description = "VPC CIDR. Must be a /16 (the module carves /20 subnets out of it)."
  type        = string
  default     = "10.40.0.0/16"
}

variable "azs" {
  description = "Availability zones to spread subnets across (one public + one private per AZ)."
  type        = list(string)
}

variable "cluster_name" {
  description = "EKS cluster name, used only for subnet discovery tags."
  type        = string
}

variable "single_nat_gateway" {
  description = "true = one shared NAT (cheaper, dev); false = one NAT per AZ (HA, prod)."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Common tags."
  type        = map(string)
  default     = {}
}
