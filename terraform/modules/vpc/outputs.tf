output "vpc_id" {
  description = "ID of the VPC provisioned by the vpc_core module."
  value       = module.vpc_core.vpc_id
}

output "pub_subnet_1a_id" {
  description = "ID of the first public subnet (index 0) from vpc_core.public_subnets, typically in AZ *a*."
  value       = module.vpc_core.public_subnets[0]
}

output "pub_subnet_2b_id" {
  description = "ID of the second public subnet (index 1) from vpc_core.public_subnets, typically in AZ *b*."
  value       = module.vpc_core.public_subnets[1]
}

output "pri_subnet_3a_id" {
  description = "ID of the first private subnet (index 0) from vpc_core.private_subnets, typically in AZ *a*."
  value       = module.vpc_core.private_subnets[0]
}

output "pri_subnet_4b_id" {
  description = "ID of the second private subnet (index 1) from vpc_core.private_subnets, typically in AZ *b*."
  value       = module.vpc_core.private_subnets[1]
}

output "sg_id" {
  description = "ID of the default admin EC2 security group."
  value       = aws_security_group.ec2_default.id
}

output "bastion_sg_id" {
  description = "Security group ID for the bastion host when enabled; null otherwise."
  value       = var.enable_bastion ? aws_security_group.bastion[0].id : null
}

output "vpce_sg_id" {
  description = "Security group ID attached to interface VPC endpoints when any are enabled; null otherwise."
  value       = local.any_interface_endpoints ? module.vpc_endpoints.security_group_id : null
}

output "ssm_vpc_endpoint_ids" {
  description = "List of interface VPC endpoint IDs for SSM, SSMMessages, and EC2Messages when enable_ssm_endpoints is true; empty list otherwise."
  value = var.enable_ssm_endpoints ? compact([
    try(module.vpc_endpoints.endpoints["ssm"].id, null),
    try(module.vpc_endpoints.endpoints["ssmmessages"].id, null),
    try(module.vpc_endpoints.endpoints["ec2messages"].id, null)
  ]) : []
}

output "ecr_cw_vpc_endpoint_ids" {
  description = "List of interface VPC endpoint IDs for ECR and CloudWatch Logs when enable_ecr_cw_endpoints is true; empty list otherwise."
  value = var.enable_ecr_cw_endpoints ? compact([
    try(module.vpc_endpoints.endpoints["ecr_api"].id, null),
    try(module.vpc_endpoints.endpoints["ecr_dkr"].id, null),
    try(module.vpc_endpoints.endpoints["logs"].id, null)
  ]) : []
}

output "monitoring_vpc_endpoint_ids" {
  description = "List containing the CloudWatch Monitoring interface VPC endpoint ID when enabled; empty list otherwise."
  value = var.enable_monitoring_endpoint ? compact([
    try(module.vpc_endpoints.endpoints["monitoring"].id, null)
  ]) : []
}

output "sts_vpc_endpoint_ids" {
  description = "List containing the STS interface VPC endpoint ID when enabled; empty list otherwise."
  value = var.enable_sts_endpoint ? compact([
    try(module.vpc_endpoints.endpoints["sts"].id, null)
  ]) : []
}

output "ec2_vpc_endpoint_ids" {
  description = "List containing the EC2 interface VPC endpoint ID when enabled; empty list otherwise."
  value = var.enable_ec2_endpoint ? compact([
    try(module.vpc_endpoints.endpoints["ec2"].id, null)
  ]) : []
}

output "sqs_vpc_endpoint_ids" {
  description = "List containing the SQS interface VPC endpoint ID when enabled; empty list otherwise."
  value = var.enable_sqs_endpoint ? compact([
    try(module.vpc_endpoints.endpoints["sqs"].id, null)
  ]) : []
}

output "eks_vpc_endpoint_ids" {
  description = "List containing the EKS interface VPC endpoint ID when enabled; empty list otherwise."
  value = var.enable_eks_endpoint ? compact([
    try(module.vpc_endpoints.endpoints["eks"].id, null)
  ]) : []
}

output "s3_gateway_vpc_endpoint_ids" {
  description = "List containing the S3 Gateway VPC endpoint ID when enabled; empty list otherwise."
  value = var.enable_s3_endpoint ? compact([
    try(module.vpc_endpoints.endpoints["s3"].id, null)
  ]) : []
}
