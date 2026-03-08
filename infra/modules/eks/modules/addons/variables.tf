variable "cluster_name" {
  type = string
}

variable "node_group_id" {
  type = string
}

variable "kubernetes_version" {
  type    = string
  default = "1.29"
}

variable "vpc_cni_role_arn" {
  description = "IAM role ARN used by the vpc-cni service account (IRSA)"
  type        = string
  default     = ""
}

variable "tags" {
  type    = map(string)
  default = {}
}
