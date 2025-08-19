variable "project_name" {
  description = "Name of the project used for tagging"
  type        = string
  default     = "KubleOps"
}

variable "region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "zone_name" {
  description = "Existing Route 53 hosted zone (apex)"
  type        = string
}

variable "acm_domain_name" {
  description = "Domain name for the ACM certificate"
  type        = string
  default     = "*.devops.firasbennacib.com"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "vpc_name" {
  description = "Name of the VPC"
  type        = string
  default     = "KubleOps-server-vpc"
}

variable "igw_name" {
  description = "Name of the Internet Gateway"
  type        = string
  default     = "KubleOps-server-igw"
}

variable "route_table_name" {
  description = "Name of the route table"
  type        = string
  default     = "KubleOps-server-rt"
}

variable "security_group_name" {
  description = "Name of the security group"
  type        = string
  default     = "KubleOps-server-sg"
}

variable "pub_subnet_1a_cidr" {
  description = "CIDR block for public subnet 1a"
  type        = string
  default     = "10.0.1.0/24"
}

variable "pub_subnet_1a_name" {
  description = "Name of public subnet 1a"
  type        = string
  default     = "pub-sub-1-a"
}

variable "pub_subnet_2b_cidr" {
  description = "CIDR block for public subnet 2b"
  type        = string
  default     = "10.0.2.0/24"
}

variable "pub_subnet_2b_name" {
  description = "Name of public subnet 2b"
  type        = string
  default     = "pub-sub-2-b"
}

variable "pri_subnet_3a_cidr" {
  description = "CIDR block for private subnet 3a"
  type        = string
  default     = "10.0.3.0/24"
}

variable "pri_subnet_3a_name" {
  description = "Name of private subnet 3a"
  type        = string
  default     = "pri-sub-3-a"
}

variable "pri_subnet_4b_cidr" {
  description = "CIDR block for private subnet 4b"
  type        = string
  default     = "10.0.4.0/24"
}

variable "pri_subnet_4b_name" {
  description = "Name of private subnet 4b"
  type        = string
  default     = "pri-sub-4-b"
}

variable "allowed_ssh_cidr" {
  description = "Public IP (CIDR) allowed to access the bastion"
  type        = string
  sensitive   = true
}

variable "enable_bastion" {
  description = "Whether to create a bastion host"
  type        = bool
  default     = false
}

variable "bastion_instance_type" {
  description = "Instance type for the bastion host"
  type        = string
  default     = "t3.micro"
}

variable "bastion_name" {
  description = "Name for the bastion host"
  type        = string
  default     = "KubleOps-bastion"
}

variable "key_name" {
  description = "Key pair name for SSH access"
  type        = string
  default     = "KubleOps-project"
}

variable "instance_name" {
  description = "Name for the admin EC2 instance"
  type        = string
  default     = "KubleOps-server"
}

variable "instance_type" {
  description = "Instance type for the admin EC2 instance"
  type        = string
  default     = "t3.medium"
}

variable "k8s_version" {
  description = "Kubernetes version to use for the EKS cluster"
  type        = string
  default     = "1.33"
}

variable "enable_network_policy" {
  description = "Enable VPC CNI NetworkPolicy engine"
  type        = bool
  default     = true
}

variable "node_group_instance_type" {
  description = "Instance type for EKS node group"
  type        = string
  default     = "m5.xlarge"
}

variable "iam_role_name" {
  description = "Name of the IAM role for EC2"
  type        = string
  default     = "KubleOps-server-iam-role"
}

variable "enable_ssm_endpoints" {
  description = "Create SSM VPC endpoints"
  type        = bool
  default     = true
}

variable "enable_ecr_cw_endpoints" {
  description = "Create ECR and CloudWatch (logs) VPC endpoints"
  type        = bool
  default     = true
}

variable "enable_monitoring_endpoint" {
  description = "Enable CloudWatch Monitoring VPC endpoint"
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
  description = "Allowed CIDRs to access interface endpoints"
  type        = list(string)
  default     = []
}

variable "queue_retention_seconds" {
  description = "Message retention (seconds) for Karpenter interruptions SQS queue"
  type        = number
  default     = 300
}

variable "dlq_max_receive_count" {
  description = "Max receives before a message is sent to the Karpenter DLQ"
  type        = number
  default     = 5
}
