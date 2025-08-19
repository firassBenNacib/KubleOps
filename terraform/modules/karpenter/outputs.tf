output "karpenter_node_role_arn" {
  description = "ARN of the Karpenter node IAM role"
  value       = aws_iam_role.karpenter_node_role.arn
}

output "karpenter_instance_profile_name" {
  description = "Instance profile name for Karpenter nodes"
  value       = aws_iam_instance_profile.karpenter_node.name
}

output "karpenter_interruption_queue_name" {
  description = "Name of the Karpenter interruptions SQS queue"
  value       = aws_sqs_queue.karpenter_interruptions.name
}

output "karpenter_interruption_queue_arn" {
  description = "ARN of the Karpenter interruptions SQS queue"
  value       = aws_sqs_queue.karpenter_interruptions.arn
}

output "karpenter_interruption_dlq_arn" {
  description = "ARN of the Karpenter interruptions DLQ"
  value       = aws_sqs_queue.karpenter_interruptions_dlq.arn
}
