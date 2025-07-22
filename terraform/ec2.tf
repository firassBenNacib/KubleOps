
resource "aws_instance" "ec2" {
  ami                    = data.aws_ami.ami.image_id  
  instance_type          = var.instance_type  
  
  key_name               = var.key_name
  
  subnet_id              = aws_subnet.public-subnet.id
  
  vpc_security_group_ids = [aws_security_group.security-group.id]
  
  iam_instance_profile   = aws_iam_instance_profile.instance-profile.name
  
  root_block_device {
    volume_size = 20
  }

  user_data = templatefile("./user-data-scripts/prepare-tools.sh", {})

  tags = {
    Name        = var.instance_name
  }
}

output "instance_id" {
  value = aws_instance.ec2.id
}

output "instance_public_ip" {
  value = aws_instance.ec2.public_ip
}