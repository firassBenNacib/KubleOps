output "zone_id" {
  description = "The ID of the Route 53 hosted zone"
  value       = data.aws_route53_zone.this.zone_id
}

output "zone_name" {
  description = "The hosted zone name"
  value       = data.aws_route53_zone.this.name
}

output "zone_arn" {
  description = "ARN of the Route 53 hosted zone"
  value       = data.aws_route53_zone.this.arn
}

output "name_servers" {
  description = "List of name servers for the hosted zone"
  value       = try(data.aws_route53_zone.this.name_servers, [])
}
