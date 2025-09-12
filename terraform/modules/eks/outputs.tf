output "eks_cluster_name" {
  description = "The name of the EKS cluster"
  value       = module.eks.cluster_name
}

output "oidc_provider_url" {
  description = "OIDC issuer URL of the EKS cluster"
  value       = module.eks.cluster_oidc_issuer_url
}

output "cluster_security_group_id" {
  description = "The control-plane security group used by the EKS API endpoint"
  value       = module.eks.cluster_security_group_id
}

output "oidc_provider_arn" {
  description = "IAM OIDC provider ARN for the EKS cluster"
  value       = module.eks.oidc_provider_arn
}

output "cluster_endpoint" {
  description = "The endpoint for your EKS Kubernetes API server"
  value       = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with your cluster"
  value       = module.eks.cluster_certificate_authority_data
}

output "cluster_ip_family" {
  description = "IP family used by the cluster (ipv4 or ipv6)"
  value       = module.eks.cluster_ip_family
}

output "cluster_service_cidr" {
  description = "The CIDR block where Kubernetes service IP addresses are assigned from"
  value       = module.eks.cluster_service_cidr
}

output "cluster_primary_security_group_id" {
  description = "EKS cluster primary SG created by the EKS service"
  value       = module.eks.cluster_primary_security_group_id
}

output "node_security_group_id" {
  description = "Security group used by worker nodes"
  value       = module.eks.node_security_group_id
}
