variable "name" {
  type        = string
  description = "Name prefix (typically the cluster name)."
}

variable "vpc_id" {
  type        = string
  description = "VPC the bastion + EKS cluster live in."
}

variable "subnet_id" {
  type        = string
  description = "Private subnet to place the bastion in (must have NAT egress so SSM + the EKS API are reachable on 443)."
}

variable "cluster_security_group_id" {
  type        = string
  description = "The EKS cluster security group (on the control-plane ENIs) to allow the bastion to reach on 443."
}

variable "instance_type" {
  type        = string
  description = "Bastion instance type."
  default     = "t3.micro"
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to bastion resources."
  default     = {}
}
