output "alb_controller_role_arn" {
  description = "IRSA role ARN for AWS Load Balancer Controller"
  value       = data.aws_iam_role.alb_irsa.arn
}

output "external_dns_role_arn" {
  description = "IRSA role ARN for ExternalDNS"
  value       = data.aws_iam_role.external_dns_irsa.arn
}

output "ebs_csi_irsa_role_arn" {
  description = "IRSA role ARN for the EBS CSI controller SA"
  value       = data.aws_iam_role.ebs_csi_irsa.arn
}
