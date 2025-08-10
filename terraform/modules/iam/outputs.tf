output "ec2_role_name" {
  value = aws_iam_role.ec2_role.name
}

output "ec2_role_arn" {
  value = aws_iam_role.ec2_role.arn
}

output "eks_cluster_role_arn" {
  value = aws_iam_role.eks_cluster_role.arn
}

output "node_group_role_arn" {
  value = aws_iam_role.node_group_role.arn
}

output "alb_controller_role_arn" {
  value = module.alb_irsa_role.iam_role_arn
}

output "ecr_irsa_role_arn" {
  value = module.ecr_irsa_role.iam_role_arn
}

output "ebs_csi_irsa_role_arn" {
  value = module.ebs_csi_irsa_role.iam_role_arn
}

output "external_dns_irsa_role_arn" {
  value = module.external_dns_irsa_role.iam_role_arn
}
