output "eks_cluster_role_arn" {
  description = "EKS control plane IAM role ARN"
  value       = data.aws_iam_role.eks_cluster.arn
}

output "node_group_role_arn" {
  description = "Node group IAM role ARN"
  value       = data.aws_iam_role.node_group.arn
}

output "admin_role_arn" {
  description = "Admin EC2 IAM role ARN"
  value       = data.aws_iam_role.admin.arn
}

output "admin_instance_profile_name" {
  description = "Admin EC2 instance profile name"
  value       = aws_iam_instance_profile.admin.name
}
