output "nat_gw_a_id" {
  description = "ID of NAT Gateway A"
  value       = aws_nat_gateway.nat_gw_a.id
}

output "nat_gw_b_id" {
  description = "ID of NAT Gateway B"
  value       = aws_nat_gateway.nat_gw_b.id
}

output "private_rt_a_id" {
  description = "ID of the private route table A (used by pri-subnet-3a)"
  value       = aws_route_table.private_rt_a.id
}

output "private_rt_b_id" {
  description = "ID of the private route table B (used by pri-subnet-4b)"
  value       = aws_route_table.private_rt_b.id
}
