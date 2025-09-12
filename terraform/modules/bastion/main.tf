data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["137112412989"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

module "bastion_instance" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "~> 6.0"

  name                   = var.bastion_instance_name
  instance_type          = var.bastion_instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [var.security_group_id]
  key_name               = var.key_name

  ami               = var.use_ssm ? null : data.aws_ami.al2023.id
  ami_ssm_parameter = var.use_ssm ? var.ami_ssm_parameter : null

  associate_public_ip_address = var.associate_public_ip
  monitoring                  = true

  volume_tags = { Name = var.bastion_instance_name }

  root_block_device = {
    encrypted = true
    type      = "gp3"
    size      = var.root_volume_size
  }

  metadata_options = {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
    instance_metadata_tags      = "disabled"
  }

  create_security_group       = false
  create_iam_instance_profile = false
  tags                        = { Name = var.bastion_instance_name }
}
