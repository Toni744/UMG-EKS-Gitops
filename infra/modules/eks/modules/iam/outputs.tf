output "cluster_role_arn" {
  description = "ARN of the EKS cluster IAM role"
  value       = aws_iam_role.eks_cluster_role.arn
}

output "node_role_arn" {
  description = "ARN of the EKS nodegroup IAM role"
  value       = aws_iam_role.node_group_role.arn
}