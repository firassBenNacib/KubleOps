output "node_group_name" {
  description = "Name of the created EKS node group"
  value       = var.node_group_name
}

output "node_group_arn" {
  description = "ARN of the EKS node group"
  value       = module.mng.node_group_arn
}
