data "aws_ami" "ubuntu_2204" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

locals {
  ssm_prefix = var.ssm_prefix != "" ? var.ssm_prefix : "/${var.cluster_name}"
}

data "template_cloudinit_config" "userdata" {
  gzip          = true
  base64_encode = true

  part {
    content_type = "text/x-shellscript"
    content = templatefile("${path.module}/user-data-scripts/prepare-tools.sh.tpl", {
      cluster_name  = var.cluster_name
      parent_zone   = var.parent_zone
      cert_domain   = var.cert_domain
      ingress_group = var.ingress_group
      ssl_redirect  = var.ssl_redirect ? "true" : "false"
      ssm_prefix    = local.ssm_prefix
    })
  }
}

module "ec2_instance" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "~> 6.0"

  name                        = var.instance_name
  ami                         = var.use_ssm ? null : data.aws_ami.ubuntu_2204.id
  ami_ssm_parameter           = var.use_ssm ? var.ami_ssm_parameter : null
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [var.security_group_id]
  key_name                    = var.key_name
  create_iam_instance_profile = false
  iam_instance_profile        = var.iam_instance_profile

  user_data_base64            = data.template_cloudinit_config.userdata.rendered
  user_data_replace_on_change = true

  monitoring         = true
  enable_volume_tags = false

  root_block_device = {
    encrypted = true
    type      = "gp3"
    size      = var.volume_size
    tags      = { Name = var.instance_name }
  }

  metadata_options = {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
    instance_metadata_tags      = "disabled"
  }

  create_security_group = false

  timeouts = {
    create = "3m"
  }

  tags = {
    Name = var.instance_name
  }
}
