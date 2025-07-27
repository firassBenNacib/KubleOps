variable "project_name" {
  description = "Name of the project used to name the EKS cluster"
  type        = string
}

variable "eks_cluster_role_arn" {
  description = "ARN of the IAM role to be assumed by the EKS control plane"
  type        = string
}

variable "pub_subnet_1a_id" {
  description = "ID of public subnet 1a"
  type        = string
}

variable "pub_subnet_2b_id" {
  description = "ID of public subnet 2b"
  type        = string
}

variable "pri_subnet_3a_id" {
  description = "ID of private subnet 3a"
  type        = string
}

variable "pri_subnet_4b_id" {
  description = "ID of private subnet 4b"
  type        = string
}

variable "k8s_version" {
  description = "Kubernetes version to use for the EKS cluster"
  type        = string
}
