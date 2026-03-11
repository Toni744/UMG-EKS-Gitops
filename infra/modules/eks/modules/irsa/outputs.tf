output "app_role_arn" {
  description = "ARN of the app IAM role"
  value       = aws_iam_role.app_role.arn
}

output "app_role_name" {
  description = "Name of the app IAM role"
  value       = aws_iam_role.app_role.name
}

output "vpc_cni_role_arn" {
  description = "ARN of the VPC CNI IAM role"
  value       = aws_iam_role.vpc_cni.arn
}
