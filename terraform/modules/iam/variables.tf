variable "project_name" {
  type = string
}

variable "iam_role_name" {
  type = string
}

variable "oidc_provider_arn" {
  type = string
}

variable "route53_zone_id" {
  description = "Hosted zone ID used by ExternalDNS for DNS updates"
  type        = string
}
