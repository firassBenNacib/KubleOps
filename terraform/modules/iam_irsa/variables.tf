variable "project_name" {
  description = "Project name used to name IAM roles and policies"
  type        = string
}

variable "oidc_provider_arn" {
  description = "IAM OIDC provider ARN for the EKS cluster"
  type        = string
}

variable "route53_zone_id" {
  description = "Hosted zone ID for ExternalDNS permissions"
  type        = string
}

variable "karpenter_node_role_arn" {
  description = "Karpenter node IAM role ARN from the karpenter module"
  type        = string
}

variable "karpenter_interruption_queue_arn" {
  description = "Karpenter interruptions SQS queue ARN from the karpenter module"
  type        = string
}
