output "alb_controller_role_arn" {
  description = "IAM role ARN for the AWS Load Balancer Controller (IRSA)"
  value       = module.iam_irsa.alb_controller_role_arn
}

output "bastion_public_ip" {
  description = "Public IP address of the bastion host (if enabled)"
  value       = var.enable_bastion ? module.bastion[0].bastion_public_ip : null
}

output "ec2_private_ip" {
  description = "Private IP address of the admin EC2 instance"
  value       = module.ec2.ec2_private_ip
}

output "karpenter_controller_role_arn" {
  description = "IAM role ARN for the Karpenter controller (IRSA)"
  value       = module.iam_irsa.karpenter_controller_role_arn
}

output "karpenter_node_role_arn" {
  description = "IAM role ARN used by Karpenter provisioned nodes"
  value       = module.karpenter.karpenter_node_role_arn
}

output "karpenter_queue_name" {
  description = "Name of the SQS interruption queue for Karpenter"
  value       = module.karpenter.karpenter_interruption_queue_name
}

output "karpenter_queue_arn" {
  description = "ARN of the SQS interruption queue for Karpenter"
  value       = module.karpenter.karpenter_interruption_queue_arn
}
