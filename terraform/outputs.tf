output "bastion_public_ip" {
  description = "Public IPv4 of the bastion host"
  value       = var.enable_bastion ? module.bastion[0].bastion_public_ip : null
}

output "ec2_private_ip" {
  description = "Private IPv4 of the admin EC2"
  value       = module.ec2.ec2_private_ip
}

output "eks_cluster_endpoint" {
  description = "EKS cluster API endpoint"
  value       = module.eks.cluster_endpoint
}

output "eks_cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.eks_cluster_name
}

output "karpenter_controller_role_arn" {
  description = "IAM role ARN assumed by the Karpenter controller"
  value       = module.karpenter.karpenter_controller_role_arn
}

output "karpenter_node_role_arn" {
  description = "IAM role ARN used by nodes provisioned by Karpenter"
  value       = module.karpenter.karpenter_node_role_arn
}

output "karpenter_queue_arn" {
  description = "SQS interruption queue ARN used by Karpenter"
  value       = module.karpenter.karpenter_interruption_queue_arn
}

output "karpenter_queue_name" {
  description = "SQS interruption queue name used by Karpenter"
  value       = module.karpenter.karpenter_interruption_queue_name
}
