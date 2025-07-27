data "aws_availability_zones" "available" {}

resource "aws_vpc" "vpc" {
  cidr_block                     = var.vpc_cidr
  instance_tenancy               = "default"
  enable_dns_hostnames           = true
  enable_dns_support             = true
  assign_generated_ipv6_cidr_block = false

  tags = {
    Name = var.vpc_name
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = var.igw_name
  }
}

resource "aws_subnet" "pub_subnet_1a" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = var.pub_subnet_1a_cidr
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name                                = var.pub_subnet_1a_name
    "kubernetes.io/cluster/${var.project_name}" = "shared"
    "kubernetes.io/role/elb"            = 1
  }
}

resource "aws_subnet" "pub_subnet_2b" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = var.pub_subnet_2b_cidr
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true

  tags = {
    Name                                = var.pub_subnet_2b_name
    "kubernetes.io/cluster/${var.project_name}" = "shared"
    "kubernetes.io/role/elb"            = 1
  }
}

resource "aws_subnet" "pri_subnet_3a" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = var.pri_subnet_3a_cidr
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = false

  tags = {
    Name                                     = var.pri_subnet_3a_name
    "kubernetes.io/cluster/${var.project_name}" = "shared"
    "kubernetes.io/role/internal-elb"        = 1
  }
}

resource "aws_subnet" "pri_subnet_4b" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = var.pri_subnet_4b_cidr
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = false

  tags = {
    Name                                     = var.pri_subnet_4b_name
    "kubernetes.io/cluster/${var.project_name}" = "shared"
    "kubernetes.io/role/internal-elb"        = 1
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = var.route_table_name
  }
}

resource "aws_route_table_association" "pub_subnet_1a" {
  subnet_id      = aws_subnet.pub_subnet_1a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "pub_subnet_2b" {
  subnet_id      = aws_subnet.pub_subnet_2b.id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "default" {
  vpc_id      = aws_vpc.vpc.id
  description = "Default SG for EC2 & SonarQube"

  ingress {
    description     = "Allow SSH from Bastion Host"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  ingress {
    description     = "Allow SonarQube from Bastion Host"
    from_port       = 9000
    to_port         = 9000
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = var.security_group_name
  }
}

resource "aws_security_group" "bastion" {
  name        = "${var.project_name}-bastion-sg"
  description = "Allow SSH access to Bastion host"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-bastion-sg"
  }
}
