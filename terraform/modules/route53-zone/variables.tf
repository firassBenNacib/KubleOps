variable "zone_name" {
  description = "Public hosted zone name"
  type        = string
}

variable "private_zone" {
  description = "Set true if this is a private hosted zone"
  type        = bool
  default     = false
}
