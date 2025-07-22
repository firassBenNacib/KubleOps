# Core Configuration

variable "region" {
  description = "AWS region"
  default     = "us-east-1"
}



variable "vpc_name" {
  description = "VPC name"
  default     = "automation-vpc"
}

variable "igw_name" {
  description = "Internet Gateway name"
  default     = "automation-igw"
}

variable "subnet_name" {
  description = "Subnet name"
  default     = "automation-subnet"
}

variable "route_table_name" {
  description = "Route table name"
  default     = "automation-route-table"
}


variable "security_group_name" {
  description = "Security group name"
  default     = "automation-sg"
}

# Instance Configuration

variable "instance_name" {
  description = "EC2 instance Name"
  default     = "automation-server"
}

variable "instance_type" {
  description = "EC2 instance type"
  default     = "t3.medium"
}



variable "key_name" {
  description = "SSH key name."
  default     = "automation-project"
}



variable "iam_role_name" {
  description = "IAM role name "
  default     = "automation-server-iam-role"
}