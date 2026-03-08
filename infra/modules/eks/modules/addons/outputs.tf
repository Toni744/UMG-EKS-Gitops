output "vpc_cni_addon_id" {
  value = aws_eks_addon.vpc_cni.id
}

output "coredns_addon_id" {
  value = aws_eks_addon.coredns.id
}

output "kube_proxy_addon_id" {
  value = aws_eks_addon.kube_proxy.id
}
