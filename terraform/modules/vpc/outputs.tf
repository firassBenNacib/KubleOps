output "vpc_id" {
  description = "ID of the created VPC"
  value       = aws_vpc.vpc.id
}

output "igw_id" {
  description = "ID of the Internet Gateway"
  value       = aws_internet_gateway.igw.id
}

output "pub_subnet_1a_id" {
  description = "ID of the public subnet 1a"
  value       = aws_subnet.pub_subnet_1a.id
}

output "pub_subnet_2b_id" {
  description = "ID of the public subnet 2b"
  value       = aws_subnet.pub_subnet_2b.id
}

output "pri_subnet_3a_id" {
  description = "ID of the private subnet 3a"
  value       = aws_subnet.pri_subnet_3a.id
}

output "pri_subnet_4b_id" {
  description = "ID of the private subnet 4b"
  value       = aws_subnet.pri_subnet_4b.id
}

output "sg_id" {
  description = "ID of the default security group"
  value       = aws_security_group.default.id
}
