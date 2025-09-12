variable "project_name" {
  description = "Project name for tagging"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR"
  type        = string
}

variable "vpc_name" {
  description = "VPC name"
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

variable "security_group_name" {
  description = "Name tag for the default security group"
  type        = string
}

variable "enable_bastion" {
  description = "Whether to create the bastion security group"
  type        = bool
}

variable "allowed_ssh_cidr" {
  description = "CIDR allowed to access the bastion via SSH (only used if enable_bastion=true)"
  type        = string
}

variable "enable_nat_gateway" {
  description = "Create NAT gateway(s) inside the VPC module"
  type        = bool
}

variable "single_nat_gateway" {
  description = "If true, create only one NAT gateway (cost saver). If false, one per AZ."
  type        = bool
}

variable "enable_ssm_endpoints" {
  description = "Enable SSM + related interface endpoints (ssm, ssmmessages, ec2messages)"
  type        = bool
}

variable "enable_ecr_cw_endpoints" {
  description = "Enable ECR (api,dkr) and CloudWatch Logs interface endpoints"
  type        = bool
}

variable "enable_monitoring_endpoint" {
  description = "Enable CloudWatch Monitoring interface endpoint"
  type        = bool
}

variable "enable_sts_endpoint" {
  description = "Enable STS interface endpoint"
  type        = bool
}

variable "enable_ec2_endpoint" {
  description = "Enable EC2 interface endpoint"
  type        = bool
}

variable "enable_sqs_endpoint" {
  description = "Enable SQS interface endpoint"
  type        = bool
}

variable "enable_eks_endpoint" {
  description = "Enable EKS interface endpoint"
  type        = bool
}

variable "enable_s3_endpoint" {
  description = "Enable S3 Gateway endpoint"
  type        = bool
}

variable "endpoints_allowed_cidrs" {
  description = "List of CIDRs allowed to access interface endpoints (defaults to VPC CIDR if empty)"
  type        = list(string)
}

variable "s3_route_table_ids" {
  description = "Route table IDs to associate with the S3 Gateway endpoint (leave empty to use the PRIVATE RTs)"
  type        = list(string)
}

variable "enable_vpc_flow_logs" {
  description = "Enable VPC Flow Logs"
  type        = bool
}

variable "vpc_flow_logs_retention_days" {
  description = "CloudWatch Logs retention for VPC Flow Logs"
  type        = number
}

variable "vpc_flow_logs_traffic_type" {
  description = "Traffic to log: ACCEPT | REJECT | ALL"
  type        = string
}

variable "karpenter_allow_public_subnets" {
  type = bool
}
