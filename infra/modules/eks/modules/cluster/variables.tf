variable "cluster_name" {
  type = string
}

variable "kubernetes_version" {
  type    = string
  default = "1.29"
}

variable "role_arn" {
  description = "IAM role ARN for the EKS cluster control plane"
  type        = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "security_group_id" {
  description = "Security group attached to the cluster"
  type        = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
