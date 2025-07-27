variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "igw_id" {
  description = "ID of the Internet Gateway"
  type        = string
}

variable "pub_subnet_1a_id" {
  description = "ID of public subnet 1a where NAT Gateway A will be created"
  type        = string
}

variable "pub_subnet_2b_id" {
  description = "ID of public subnet 2b where NAT Gateway B will be created"
  type        = string
}

variable "pri_subnet_3a_id" {
  description = "ID of private subnet 3a to associate with NAT Gateway A"
  type        = string
}

variable "pri_subnet_4b_id" {
  description = "ID of private subnet 4b to associate with NAT Gateway B"
  type        = string
}
