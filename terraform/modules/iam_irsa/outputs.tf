output "alb_controller_role_arn" {
  description = "IRSA role ARN for AWS Load Balancer Controller"
  value       = module.alb_irsa_role.iam_role_arn
}

output "ebs_csi_role_arn" {
  description = "IRSA role ARN for EBS CSI controller"
  value       = module.ebs_csi_irsa_role.iam_role_arn
}

output "external_dns_role_arn" {
  description = "IRSA role ARN for ExternalDNS"
  value       = module.external_dns_irsa_role.iam_role_arn
}

output "fluent_bit_role_arn" {
  description = "IRSA role ARN for Fluent Bit"
  value       = module.fluent_bit_irsa_role.iam_role_arn
}

output "cloudwatch_agent_role_arn" {
  description = "IRSA role ARN for CloudWatch Agent"
  value       = module.cw_agent_irsa_role.iam_role_arn
}

output "karpenter_controller_role_arn" {
  description = "IRSA role ARN for Karpenter controller"
  value       = module.karpenter_irsa_role.iam_role_arn
}
