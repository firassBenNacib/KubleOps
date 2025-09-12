variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "tags" {
  description = "Tags to apply to Karpenter resources"
  type        = map(string)
}

variable "ssm_prefix" {
  description = "SSM Parameter Store prefix for writing Karpenter outputs"
  type        = string
}
