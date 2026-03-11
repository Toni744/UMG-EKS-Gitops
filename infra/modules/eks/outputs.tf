output "cluster_id" {
  description = "EKS cluster ID"
  value       = module.cluster.cluster_id
}

output "cluster_endpoint" {
  description = "Kubernetes API endpoint"
  value       = module.cluster.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate for cluster access"
  value       = module.cluster.cluster_certificate_authority_data
  sensitive   = true
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.networking.vpc_id
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = module.networking.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.networking.private_subnet_ids
}

output "configure_kubectl" {
  description = "Command to configure kubectl"
  value       = "aws eks update-kubeconfig --region us-east-1 --name ${module.cluster.cluster_id}"
}
