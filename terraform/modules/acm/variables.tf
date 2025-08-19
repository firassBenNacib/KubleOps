variable "domain_name" {
  description = "Primary domain for the certificate"
  type        = string
}

variable "subject_alternative_names" {
  description = "Optional SANs "
  type        = list(string)
  default     = []
}

variable "route53_zone_id" {
  description = "Hosted zone ID where DNS validation records should be created"
  type        = string
}

variable "tags" {
  description = "Tags to apply to the ACM certificate"
  type        = map(string)

}
