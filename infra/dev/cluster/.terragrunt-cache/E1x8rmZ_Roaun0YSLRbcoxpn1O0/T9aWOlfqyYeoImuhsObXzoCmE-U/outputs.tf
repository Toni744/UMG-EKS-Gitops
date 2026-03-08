output "cluster_id" {
  description = "The ID/name of the EKS cluster"
  value       = module.cluster.cluster_id
}

output "cluster_arn" {
  description = "The ARN of the EKS cluster"
  value       = module.cluster.cluster_arn
}

output "cluster_endpoint" {
  description = "Endpoint for your Kubernetes API server"
  value       = module.cluster.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = module.cluster.cluster_certificate_authority_data
  sensitive   = true
}

output "cluster_oidc_issuer_url" {
  description = "The URL on the EKS cluster OIDC Issuer"
  value       = module.cluster.cluster_oidc_issuer_url
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = module.iam.cluster_sg_id
}

output "node_group_id" {
  description = "EKS node group ID"
  value       = module.node_group.node_group_id
}

output "node_group_arn" {
  description = "ARN of the EKS Node Group"
  value       = module.node_group.node_group_arn
}

output "node_security_group_id" {
  description = "Security group ID of worker nodes"
  value       = module.iam.node_sg_id
}

output "vpc_id" {
  description = "The ID of the VPC"
  value       = module.networking.vpc_id
}

output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = module.networking.public_subnet_ids
}

output "private_subnet_ids" {
  description = "List of private subnet IDs"
  value       = module.networking.private_subnet_ids
}

output "nat_gateway_ips" {
  description = "Elastic IPs of NAT Gateways"
  value       = module.networking.nat_gateway_ips
}

output "vpc_cni_role_arn" {
  description = "IAM role ARN used by VPC CNI (IRSA)"
  value       = module.irsa.vpc_cni_role_arn
}

output "app_role_arn" {
  description = "IAM role ARN for application service account (IRSA)"
  value       = module.irsa.app_role_arn
}

output "configure_kubectl" {
  description = "Command to configure kubectl"
  value       = "aws eks update-kubeconfig --region us-east-1 --name ${module.cluster.cluster_id}"
}
