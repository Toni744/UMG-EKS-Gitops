output "vpc_cni_role_arn" {
  value = aws_iam_role.vpc_cni.arn
}

output "app_role_arn" {
  description = "ARN of the application IAM role for IRSA"
  value       = aws_iam_role.app_role.arn
}
