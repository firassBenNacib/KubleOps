variable "cluster_name" {
  type        = string
  description = "EKS cluster name"
}

variable "enable_network_policy" {
  type        = bool
  description = "Enable network policy via VPC CNI config"
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to EKS add-ons"
}

variable "ebs_csi_role_arn" {
  type        = string
  description = "IRSA role ARN for aws-ebs-csi-driver"
}
