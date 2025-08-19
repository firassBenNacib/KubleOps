resource "aws_eip" "nat_gw_a_eip" {
  tags = {
    Name = "nat-gw-eip-a"
  }
}

resource "aws_eip" "nat_gw_b_eip" {
  tags = {
    Name = "nat-gw-eip-b"
  }
}

resource "aws_nat_gateway" "nat_gw_a" {
  allocation_id = aws_eip.nat_gw_a_eip.id
  subnet_id     = var.pub_subnet_1a_id

  tags = {
    Name = "nat-gw-a"
  }
}

resource "aws_nat_gateway" "nat_gw_b" {
  allocation_id = aws_eip.nat_gw_b_eip.id
  subnet_id     = var.pub_subnet_2b_id

  tags = {
    Name = "nat-gw-b"
  }
}

resource "aws_route_table" "private_rt_a" {
  vpc_id = var.vpc_id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw_a.id
  }

  tags = {
    Name = "private-rt-a"
  }
}

resource "aws_route_table_association" "pri_subnet_3a_assoc" {
  subnet_id      = var.pri_subnet_3a_id
  route_table_id = aws_route_table.private_rt_a.id
}

resource "aws_route_table" "private_rt_b" {
  vpc_id = var.vpc_id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw_b.id
  }

  tags = {
    Name = "private-rt-b"
  }
}

resource "aws_route_table_association" "pri_subnet_4b_assoc" {
  subnet_id      = var.pri_subnet_4b_id
  route_table_id = aws_route_table.private_rt_b.id
}
