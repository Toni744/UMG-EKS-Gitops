resource "aws_eks_cluster" "main" {
  name    = var.cluster_name
  version = var.kubernetes_version
  role_arn = var.role_arn

  vpc_config {
    subnet_ids              = var.subnet_ids
    security_groups         = [var.security_group_id]
    endpoint_private_access = true
    endpoint_public_access  = true
  }

  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  tags = merge(var.tags, { Name = var.cluster_name })
}

# export OIDC issuer URL for other modules (IRSA etc)
output "cluster_oidc_issuer_url" {
  value = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

output "cluster_id" {
  value = aws_eks_cluster.main.id
}

output "cluster_arn" {
  value = aws_eks_cluster.main.arn
}

output "cluster_endpoint" {
  value = aws_eks_cluster.main.endpoint
}

output "cluster_certificate_authority_data" {
  value     = aws_eks_cluster.main.certificate_authority[0].data
  sensitive = true
}