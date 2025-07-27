output "oidc_provider_arn" {
  description = "The ARN of the IAM OpenID Connect Provider"
  value       = aws_iam_openid_connect_provider.eks_oidc.arn
}
