output "cluster_role_arn" {
  description = "ARN of the EKS cluster IAM role"
  value       = aws_iam_role.eks_cluster_role.arn
}

output "node_role_arn" {
  description = "ARN of the EKS nodegroup IAM role"
  value       = aws_iam_role.node_group_role.arn
}

output "cluster_sg_id" {
  description = "Security group ID for the cluster control plane"
  value       = aws_security_group.eks_cluster.id
}

output "node_sg_id" {
  description = "Security group ID for worker nodes"
  value       = aws_security_group.node_group.id
}