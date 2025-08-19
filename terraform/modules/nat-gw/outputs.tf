output "nat_gw_a_id" {
  description = "ID of NAT Gateway A"
  value       = aws_nat_gateway.nat_gw_a.id
}

output "nat_gw_b_id" {
  description = "ID of NAT Gateway B"
  value       = aws_nat_gateway.nat_gw_b.id
}

output "private_rt_a_id" {
  description = "ID of the private route table A"
  value       = aws_route_table.private_rt_a.id
}

output "private_rt_b_id" {
  description = "ID of the private route table B"
  value       = aws_route_table.private_rt_b.id
}

output "private_route_table_ids" {
  description = "List of IDs of the private route tables"
  value = [
    aws_route_table.private_rt_a.id,
    aws_route_table.private_rt_b.id
  ]
}
