resource "aws_eks_cluster" "main" {
  name    = var.cluster_name
  version = var.kubernetes_version
  role_arn = var.role_arn

  vpc_config {
    subnet_ids              = var.subnet_ids
    security_group_ids      = [var.security_group_id]
    endpoint_private_access = true
    endpoint_public_access  = true
  }

  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  tags = merge(var.tags, { Name = var.cluster_name })
}