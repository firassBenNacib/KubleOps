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
  description = "Subnet ID"
  type        = string
}

variable "security_group_id" {
  description = "Security Group ID"
  type        = string
}

variable "volume_size" {
  description = "Root volume size in GB"
  type        = number
}

variable "use_ssm" {
  description = "Resolve AMI from SSM parameter"
  type        = bool
}

variable "ami_ssm_parameter" {
  description = "SSM parameter containing AMI ID"
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "parent_zone" {
  description = "Parent Route53 zone"
  type        = string
}

variable "cert_domain" {
  description = "ACM certificate domain to use"
  type        = string
}

variable "ingress_group" {
  description = "ALB ingress group name"
  type        = string
}

variable "ssl_redirect" {
  description = "Force ALB HTTPS redirect"
  type        = bool
}

variable "ssm_prefix" {
  description = "Base SSM param path (e.g. /KubleOps)"
  type        = string
}

variable "iam_instance_profile" {
  type        = string
  description = "Existing instance profile name to attach to the EC2 instance"
}
