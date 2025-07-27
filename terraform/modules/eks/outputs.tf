output "eks_cluster_name" {
  description = "The name (ID) of the EKS cluster"
  value       = aws_eks_cluster.eks_cluster.id
}

output "oidc_provider_url" {
  description = "OIDC issuer URL of the EKS cluster"
  value       = aws_eks_cluster.eks_cluster.identity[0].oidc[0].issuer
}

output "oidc_provider_arn" {
  description = "OIDC issuer URL"
  value       = aws_eks_cluster.eks_cluster.identity[0].oidc[0].issuer
}
