output "node_group_id" {
  value = aws_eks_node_group.main.id
}

output "node_group_arn" {
  value = aws_eks_node_group.main.arn
}

output "node_group_status" {
  value = aws_eks_node_group.main.status
}