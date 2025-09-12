output "certificate_arn" {
  description = "ARN of the AWS ACM certificate created by this module."
  value       = aws_acm_certificate.this.arn
}

