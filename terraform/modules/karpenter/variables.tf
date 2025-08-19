variable "project_name" {
  description = "Project name used to build default resource names"
  type        = string
}

variable "queue_retention_seconds" {
  description = "Message retention for the interruptions queue"
  type        = number
}

variable "dlq_max_receive_count" {
  description = "Max receives before messages go to DLQ"
  type        = number
}
