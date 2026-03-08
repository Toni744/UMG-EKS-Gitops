variable "cluster_name" {
  description = "Name of the cluster (used for naming resources)"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "tags" {
  description = "Tags applied to all networking resources"
  type        = map(string)
  default     = {}
}

variable "single_nat_gateway" {
  description = "Use single NAT GW (dev) or per-AZ (prod)"
  type        = bool
  default     = false
}