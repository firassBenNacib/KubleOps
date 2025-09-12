variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
}

variable "iam_role_name" {
  description = "Name of the IAM role for the admin EC2 host"
  type        = string
}

variable "create_bastion_role" {
  description = "Create a bastion IAM role with SSM permissions"
  type        = bool
}

variable "bastion_role_name" {
  description = "Name for the bastion IAM role"
  type        = string
}

variable "create_bastion_instance_profile" {
  description = "Also create an instance profile for the bastion"
  type        = bool
}

variable "bastion_instance_profile_name" {
  description = "Name for the bastion instance profile"
  type        = string
}

variable "attach_cloudwatch_agent_to_bastion" {
  description = "Attach CloudWatchAgentServerPolicy to the bastion role"
  type        = bool
}
