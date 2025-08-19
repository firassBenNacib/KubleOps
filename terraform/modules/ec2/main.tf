data "aws_ami" "ubuntu_latest" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  owners = ["099720109477"]
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = var.instance_profile_name
  role = var.iam_role_name
}

resource "aws_instance" "ec2_instance" {
  ami                    = data.aws_ami.ubuntu_latest.image_id
  instance_type          = var.instance_type
  key_name               = var.key_name
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [var.security_group_id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name

  root_block_device {
    volume_size = var.volume_size
  }

  user_data_base64 = filebase64("${path.module}/user-data-scripts/prepare-tools.sh")

  tags = {
    Name = var.instance_name
  }
}
