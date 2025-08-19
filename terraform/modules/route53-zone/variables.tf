variable "zone_name" {
  description = "Name of the Route 53 hosted zone"
  type        = string
}


variable "private_zone" {
  description = "Set true if this is a private hosted zone"
  type        = bool
  default     = false
}
