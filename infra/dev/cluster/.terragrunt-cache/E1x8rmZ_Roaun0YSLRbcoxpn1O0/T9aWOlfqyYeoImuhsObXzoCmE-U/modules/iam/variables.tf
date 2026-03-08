variable "cluster_name" {
  description = "Cluster name used in IAM role naming"
  type        = string
}

variable "tags" {
  description = "Tags to apply to IAM resources"
  type        = map(string)
  default     = {}
}

variable "vpc_id" {
  description = "VPC ID for security groups"
  type        = string
}
