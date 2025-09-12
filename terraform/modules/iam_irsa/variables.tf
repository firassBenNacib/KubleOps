variable "project_name" {
  description = "Project name used to name IAM roles and policies"
  type        = string
}

variable "oidc_provider_arn" {
  description = "EKS cluster OIDC provider ARN"
  type        = string
}

variable "route53_zone_id" {
  description = "Hosted Zone ID to scope ExternalDNS permissions"
  type        = string
}
