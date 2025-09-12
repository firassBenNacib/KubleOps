variable "bastion_instance_type" {
  description = "EC2 instance type for the bastion host"
  type        = string
}

variable "bastion_instance_name" {
  description = "Name tag for the bastion host"
  type        = string
}

variable "key_name" {
  description = "Name of the SSH key pair to use for the bastion host"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID where the bastion host will be launched"
  type        = string
}

variable "security_group_id" {
  description = "Security Group ID to attach to the bastion host"
  type        = string
}

variable "use_ssm" {
  description = "Whether to select the AMI via SSM parameter or via a data source lookup"
  type        = bool
}

variable "ami_ssm_parameter" {
  description = "SSM public parameter name that points to the desired AMI"
  type        = string
}

variable "associate_public_ip" {
  description = "Whether to associate a public IP address to the bastion host"
  type        = bool
}

variable "root_volume_size" {
  description = "Root EBS volume size in GiB for the bastion host"
  type        = number
}


