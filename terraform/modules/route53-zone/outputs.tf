output "zone_id"   { value = data.aws_route53_zone.this.zone_id }
output "zone_name" { value = data.aws_route53_zone.this.name }
output "zone_arn"  { value = data.aws_route53_zone.this.arn }
output "name_servers" {
  value = try(data.aws_route53_zone.this.name_servers, [])
}
