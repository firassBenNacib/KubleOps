variable "region" {
  description = "AWS region"
  type        = string
}

variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
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

variable "vpc_name" {
  description = "Name tag for the VPC"
  type        = string
}

variable "igw_name" {
  description = "Name tag for the Internet Gateway"
  type        = string
}

variable "subnet_name" {
  description = "Common name prefix for subnets"
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

variable "allowed_ssh_cidr" {
  description = "CIDR block allowed to access the bastion host via SSH"
  type        = string
}
