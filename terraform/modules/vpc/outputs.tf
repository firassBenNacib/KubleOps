output "vpc_id" {
  description = "ID of the created VPC"
  value       = aws_vpc.vpc.id
}

output "igw_id" {
  description = "ID of the Internet Gateway"
  value       = aws_internet_gateway.igw.id
}

output "pub_subnet_1a_id" {
  description = "ID of public subnet 1a"
  value       = aws_subnet.pub_subnet_1a.id
}

output "pub_subnet_2b_id" {
  description = "ID of public subnet 2b"
  value       = aws_subnet.pub_subnet_2b.id
}

output "pri_subnet_3a_id" {
  description = "ID of private subnet 3a"
  value       = aws_subnet.pri_subnet_3a.id
}

output "pri_subnet_4b_id" {
  description = "ID of private subnet 4b"
  value       = aws_subnet.pri_subnet_4b.id
}

output "sg_id" {
  description = "ID of the default security group"
  value       = aws_security_group.default.id
}

output "bastion_sg_id" {
  description = "ID of the bastion security group (if enabled)"
  value       = var.enable_bastion ? aws_security_group.bastion[0].id : null
}



output "ssm_vpc_endpoint_ids" {
  description = "IDs of SSM-related VPC endpoints (if enabled)"
  value = var.enable_ssm_endpoints ? [
    aws_vpc_endpoint.ssm[0].id,
    aws_vpc_endpoint.ssmmessages[0].id,
    aws_vpc_endpoint.ec2messages[0].id
  ] : []
}

output "ecr_cw_vpc_endpoint_ids" {
  description = "IDs of ECR and CloudWatch VPC endpoints (if enabled)"
  value = var.enable_ecr_cw_endpoints ? [
    aws_vpc_endpoint.ecr_api[0].id,
    aws_vpc_endpoint.ecr_dkr[0].id,
    aws_vpc_endpoint.logs[0].id,
    aws_vpc_endpoint.monitoring[0].id
  ] : []
}

output "monitoring_vpc_endpoint_ids" {
  description = "IDs of CloudWatch Monitoring VPC endpoints (if enabled)"
  value       = var.enable_monitoring_endpoint ? [aws_vpc_endpoint.monitoring[0].id] : []
}


output "sts_vpc_endpoint_ids" {
  description = "IDs of STS VPC endpoints (if enabled)"
  value       = var.enable_sts_endpoint ? [aws_vpc_endpoint.sts[0].id] : []
}

output "ec2_vpc_endpoint_ids" {
  description = "IDs of EC2 VPC endpoints (if enabled)"
  value       = var.enable_ec2_endpoint ? [aws_vpc_endpoint.ec2[0].id] : []
}

output "sqs_vpc_endpoint_ids" {
  description = "IDs of SQS VPC endpoints (if enabled)"
  value       = var.enable_sqs_endpoint ? [aws_vpc_endpoint.sqs[0].id] : []
}

output "eks_vpc_endpoint_ids" {
  description = "IDs of EKS VPC endpoints (if enabled)"
  value       = var.enable_eks_endpoint ? [aws_vpc_endpoint.eks[0].id] : []
}

output "s3_gateway_vpc_endpoint_ids" {
  description = "IDs of S3 Gateway VPC endpoints (if enabled)"
  value       = var.enable_s3_endpoint ? [aws_vpc_endpoint.s3[0].id] : []
}

