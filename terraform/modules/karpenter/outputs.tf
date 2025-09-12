output "karpenter_controller_role_arn" {
  description = "IAM role ARN for the Karpenter controller"
  value       = module.eks_karpenter.iam_role_arn
}

output "karpenter_node_role_arn" {
  description = "ARN of the Karpenter node IAM role"
  value       = module.eks_karpenter.node_iam_role_arn
}

output "karpenter_instance_profile_name" {
  description = "Instance profile name for Karpenter nodes"
  value       = module.eks_karpenter.instance_profile_name
}

output "karpenter_interruption_queue_name" {
  description = "Name of the Karpenter interruptions SQS queue"
  value       = module.eks_karpenter.queue_name
}

output "karpenter_interruption_queue_arn" {
  description = "ARN of the Karpenter interruptions SQS queue"
  value       = module.eks_karpenter.queue_arn
}
