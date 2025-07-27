variable "bastion_instance_type" {
  description = "Instance type for the bastion host"
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
  description = "Subnet ID to launch the bastion host in"
  type        = string
}

variable "security_group_id" {
  description = "ID of the security group to attach to the bastion host"
  type        = string
}
