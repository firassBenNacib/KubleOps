variable "iam_role_name" {
  description = "Name of the IAM role for EC2"
  default     = "KubleOps-server-iam-role"
}

variable "igw_name" {
  description = "Name of the Internet Gateway"
  default     = "KubleOps-server-igw"
}

variable "zone_name" {
  description = "Existing Route 53 hosted zone (apex)"
  type        = string
}

variable "instance_name" {
  description = "Name for the EC2 instance"
  default     = "KubleOps-server"
}

variable "instance_type" {
  description = "Instance type for the EC2 instance"
  default     = "t3.medium"
}

variable "node_group_instance_type" {
  description = "Instance type for EKS node group"
  default     = "m5.xlarge"
}

variable "key_name" {
  description = "Key pair name for EC2 SSH access"
  default     = "KubleOps-project"
}

variable "pri_subnet_3a_cidr" {
  description = "CIDR block for private subnet 3a"
  default     = "10.0.3.0/24"
}

variable "pri_subnet_3a_name" {
  description = "Name of private subnet 3a"
  default     = "pri-sub-3-a"
}

variable "pri_subnet_4b_cidr" {
  description = "CIDR block for private subnet 4b"
  default     = "10.0.4.0/24"
}

variable "pri_subnet_4b_name" {
  description = "Name of private subnet 4b"
  default     = "pri-sub-4-b"
}

variable "project_name" {
  description = "Name of the project used for tagging"
  default     = "KubleOps"
}

variable "k8s_version" {
  description = "Kubernetes version to use for the EKS cluster"
  default     = "1.33"
}

variable "pub_subnet_1a_cidr" {
  description = "CIDR block for public subnet 1a"
  default     = "10.0.1.0/24"
}

variable "pub_subnet_1a_name" {
  description = "Name of public subnet 1a"
  default     = "pub-sub-1-a"
}

variable "pub_subnet_2b_cidr" {
  description = "CIDR block for public subnet 2b"
  default     = "10.0.2.0/24"
}

variable "pub_subnet_2b_name" {
  description = "Name of public subnet 2b"
  default     = "pub-sub-2-b"
}

variable "region" {
  description = "AWS region to deploy resources"
  default     = "us-east-1"
}

variable "route_table_name" {
  description = "Name of the route table"
  default     = "KubleOps-server-rt"
}

variable "security_group_name" {
  description = "Name of the security group"
  default     = "KubleOps-server-sg"
}

variable "subnet_name" {
  description = "Base name prefix for all subnets"
  default     = "KubleOps-server-subnet"
}

variable "allowed_ssh_cidr" {
  description = "Public IP allowed to access the bastion"
  type        = string
  sensitive   = true
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  default     = "10.0.0.0/16"
}

variable "vpc_name" {
  description = "Name of the VPC"
  default     = "KubleOps-server-vpc"
}

variable "bastion_instance_type" {
  description = "Instance type for the bastion host"
  default     = "t3.micro"
}

variable "bastion_name" {
  description = "Name for the bastion host"
  default     = "KubleOps-bastion"
}
