variable "instance_name" {
  description = "Name of the EC2 instance"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
}

variable "key_name" {
  description = "SSH key pair name"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID to launch EC2 instance in"
  type        = string
}

variable "security_group_id" {
  description = "Security Group ID to attach to the EC2 instance"
  type        = string
}

variable "iam_role_name" {
  description = "IAM role to attach to the EC2 instance"
  type        = string
}

variable "instance_profile_name" {
  description = "Name of the IAM instance profile"
  type        = string
}

variable "volume_size" {
  description = "Size of the root volume in GB"
  type        = number
}
