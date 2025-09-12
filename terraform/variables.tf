variable "project_name" {
  description = "Project name used for tagging and resource names"
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

variable "route53_private_zone" {
  description = "Whether the Route53 hosted zone is private"
  type        = bool
  default     = false
}

variable "acm_domain_name" {
  description = "Domain name (wildcard or FQDN) for the ACM certificate"
  type        = string
  default     = "*.devops.firasbennacib.com"
}

variable "acm_subject_alternative_names" {
  description = "Additional DNS names (SANs) for the ACM certificate"
  type        = list(string)
  default     = []
}

variable "acm_tags" {
  description = "Extra tags for the ACM certificate"
  type        = map(string)
  default     = {}
}

variable "vpc_cidr" {
  description = "VPC CIDR"
  type        = string
  default     = "10.0.0.0/16"
}

variable "vpc_name" {
  description = "VPC name"
  type        = string
  default     = "KubleOps-server-vpc"
}

variable "security_group_name" {
  description = "Base SG name"
  type        = string
  default     = "KubleOps-server-sg"
}

variable "pub_subnet_1a_cidr" {
  type    = string
  default = "10.0.1.0/24"
}

variable "pub_subnet_1a_name" {
  type    = string
  default = "pub-sub-1-a"
}

variable "pub_subnet_2b_cidr" {
  type    = string
  default = "10.0.2.0/24"
}

variable "pub_subnet_2b_name" {
  type    = string
  default = "pub-sub-2-b"
}

variable "pri_subnet_3a_cidr" {
  type    = string
  default = "10.0.16.0/20"
}

variable "pri_subnet_3a_name" {
  type    = string
  default = "pri-sub-3-a"
}

variable "pri_subnet_4b_cidr" {
  type    = string
  default = "10.0.32.0/20"
}

variable "pri_subnet_4b_name" {
  type    = string
  default = "pri-sub-4-b"
}

variable "allowed_ssh_cidr" {
  description = "Public IP (CIDR) allowed to access the bastion"
  type        = string
  sensitive   = true
}

variable "enable_ssm_endpoints" {
  type    = bool
  default = true
}

variable "enable_ecr_cw_endpoints" {
  type    = bool
  default = true
}

variable "enable_monitoring_endpoint" {
  type    = bool
  default = true
}

variable "enable_sts_endpoint" {
  type    = bool
  default = true
}

variable "enable_ec2_endpoint" {
  type    = bool
  default = true
}

variable "enable_sqs_endpoint" {
  type    = bool
  default = false
}

variable "enable_eks_endpoint" {
  type    = bool
  default = true
}

variable "enable_s3_endpoint" {
  type    = bool
  default = false
}

variable "endpoints_allowed_cidrs" {
  description = "Allowed CIDRs to access interface endpoints"
  type        = list(string)
  default     = []
}

variable "enable_nat_gateway" {
  type    = bool
  default = true
}

variable "single_nat_gateway" {
  type    = bool
  default = false
}

variable "enable_vpc_flow_logs" {
  type    = bool
  default = true
}

variable "vpc_flow_logs_retention_days" {
  type    = number
  default = 30
}

variable "vpc_flow_logs_traffic_type" {
  type    = string
  default = "ALL"
}

variable "s3_route_table_ids" {
  description = "Route tables for S3 gateway endpoint routes (optional)"
  type        = list(string)
  default     = []
}

variable "k8s_version" {
  description = "Kubernetes version for the EKS control plane"
  type        = string
  default     = "1.32"
}

variable "node_group_instance_type" {
  type    = string
  default = "m5.xlarge"
}

variable "node_group_disk_size" {
  type    = number
  default = 20
}

variable "node_group_desired_size" {
  type    = number
  default = 2
}

variable "node_group_min_size" {
  type    = number
  default = 1
}

variable "node_group_max_size" {
  type    = number
  default = 10
}

variable "iam_role_name" {
  description = "IAM role name attached to the admin EC2 instance"
  type        = string
  default     = "KubleOps-server-iam-role"
}

variable "instance_name" {
  type    = string
  default = "KubleOps-server"
}

variable "instance_type" {
  type    = string
  default = "t3.medium"
}

variable "key_name" {
  type    = string
  default = "KubleOps-project"
}

variable "use_ssm" {
  type    = bool
  default = true
}

variable "ami_ssm_parameter" {
  type    = string
  default = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

variable "ec2_root_volume_size" {
  type    = number
  default = 20
}

variable "ingress_group" {
  description = "ALB ingress group name"
  type        = string
  default     = "kubleops-public"
}

variable "ssl_redirect" {
  description = "Force ALB HTTPS redirect"
  type        = bool
  default     = true
}

variable "ssm_prefix" {
  description = "Base SSM param path (leave empty to let the module compute \"/<cluster_name>\")"
  type        = string
  default     = ""
}

variable "enable_bastion" {
  type    = bool
  default = false
}

variable "bastion_name" {
  type    = string
  default = "KubleOps-bastion"
}

variable "bastion_instance_type" {
  type    = string
  default = "t3.micro"
}

variable "bastion_associate_public_ip" {
  type    = bool
  default = true
}

variable "bastion_use_ssm" {
  type    = bool
  default = true
}

variable "bastion_ami_ssm_parameter" {
  type    = string
  default = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

variable "bastion_root_volume_size" {
  type    = number
  default = 10
}

variable "create_bastion_instance_profile" {
  type    = bool
  default = true
}

variable "attach_cloudwatch_agent_to_bastion" {
  type    = bool
  default = true
}

variable "karpenter_tags" {
  description = "Extra tags merged into the Karpenter module resources"
  type        = map(string)
  default     = {}
}

variable "node_group_name" {
  description = "Override the EKS managed node group name. Leave empty to default to <cluster>-node-group."
  type        = string
  default     = ""
}

variable "bastion_role_name" {
  description = "Override the bastion IAM role name. Leave empty to default to <project>-bastion-role."
  type        = string
  default     = ""
}

variable "bastion_instance_profile_name" {
  description = "Override the bastion instance profile name. Leave empty to default to <project>-bastion-profile."
  type        = string
  default     = ""
}

variable "karpenter_allow_public_subnets" {
  description = "Also tag public subnets for Karpenter discovery"
  type        = bool
  default     = false
}
