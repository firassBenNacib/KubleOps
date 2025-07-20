# Core Configuration

variable "region" {
  description = "AWS region"
  default     = "us-east-1"
}



variable "vpc_name" {
  description = "VPC name"
  default     = "argocd-vpc"
}

variable "igw_name" {
  description = "Internet Gateway name"
  default     = "argoc-igw"
}

variable "subnet_name" {
  description = "Subnet name"
  default     = "argocd-subnet"
}

variable "route_table_name" {
  description = "Route table name"
  default     = "argocd-route-table"
}


variable "security_group_name" {
  description = "Security group name"
  default     = "argocd-sg"
}

# Instance Configuration

variable "instance_name" {
  description = "EC2 instance Name"
  default     = "argocd-server"
}

variable "instance_type" {
  description = "EC2 instance type"
  default     = "t2.2xlarge"
}



variable "key_name" {
  description = "SSH key name."
  default     = "argocd-project"
}



variable "iam_role_name" {
  description = "IAM role name "
  default     = "argocd-server-iam-role"
}