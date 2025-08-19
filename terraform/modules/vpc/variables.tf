variable "region" {
  description = "AWS region where resources will be created"
  type        = string
}

variable "project_name" {
  description = "Name of the project used for tagging resources"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "vpc_name" {
  description = "Name tag for the VPC"
  type        = string
}

variable "igw_name" {
  description = "Name tag for the Internet Gateway"
  type        = string
}

variable "pub_subnet_1a_cidr" {
  description = "CIDR block for public subnet 1a"
  type        = string
}

variable "pub_subnet_2b_cidr" {
  description = "CIDR block for public subnet 2b"
  type        = string
}

variable "pri_subnet_3a_cidr" {
  description = "CIDR block for private subnet 3a"
  type        = string
}

variable "pri_subnet_4b_cidr" {
  description = "CIDR block for private subnet 4b"
  type        = string
}

variable "pub_subnet_1a_name" {
  description = "Name tag for public subnet 1a"
  type        = string
}

variable "pub_subnet_2b_name" {
  description = "Name tag for public subnet 2b"
  type        = string
}

variable "pri_subnet_3a_name" {
  description = "Name tag for private subnet 3a"
  type        = string
}

variable "pri_subnet_4b_name" {
  description = "Name tag for private subnet 4b"
  type        = string
}

variable "route_table_name" {
  description = "Name tag for the public route table"
  type        = string
}

variable "security_group_name" {
  description = "Name tag for the default security group"
  type        = string
}

variable "enable_bastion" {
  description = "Whether to enable the bastion host"
  type        = bool
}

variable "allowed_ssh_cidr" {
  description = "CIDR block allowed to access the bastion host via SSH"
  type        = string
}

variable "enable_ssm_endpoints" {
  description = "Enable SSM and related VPC endpoints"
  type        = bool
  default     = true
}

variable "enable_ecr_cw_endpoints" {
  description = "Enable ECR and CloudWatch VPC endpoints"
  type        = bool
  default     = true
}

variable "enable_sts_endpoint" {
  description = "Enable STS VPC endpoint"
  type        = bool
  default     = true
}

variable "enable_ec2_endpoint" {
  description = "Enable EC2 VPC endpoint"
  type        = bool
  default     = true
}

variable "enable_sqs_endpoint" {
  description = "Enable SQS VPC endpoint"
  type        = bool
  default     = false
}

variable "enable_eks_endpoint" {
  description = "Enable EKS VPC endpoint"
  type        = bool
  default     = true
}

variable "enable_s3_endpoint" {
  description = "Enable S3 Gateway endpoint"
  type        = bool
  default     = true
}

variable "endpoints_allowed_cidrs" {
  description = "List of CIDRs allowed to access VPC endpoints"
  type        = list(string)
}

variable "s3_route_table_ids" {
  description = "Route table IDs to associate with the S3 Gateway endpoint (usually private RTs)"
  type        = list(string)
}

variable "enable_monitoring_endpoint" {
  description = "Enable CloudWatch Monitoring VPC endpoint"
  type        = bool
  default     = true
}
