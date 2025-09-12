data "aws_availability_zones" "available" {}

data "aws_iam_policy_document" "s3_gateway_allow_get_any" {
  statement {
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["arn:aws:s3:::*/*"]
    principals {
      type        = "AWS"
      identifiers = ["*"]
    }
  }
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 2)

  any_interface_endpoints = (
    var.enable_ssm_endpoints ||
    var.enable_ecr_cw_endpoints ||
    var.enable_monitoring_endpoint ||
    var.enable_sts_endpoint ||
    var.enable_ec2_endpoint ||
    var.enable_sqs_endpoint ||
    var.enable_eks_endpoint
  )

  vpce_ingress_cidrs = length(var.endpoints_allowed_cidrs) > 0 ? var.endpoints_allowed_cidrs : [var.vpc_cidr]

  endpoints_map = merge(
    var.enable_ssm_endpoints ? {
      ssm = {
        service             = "ssm"
        private_dns_enabled = true
        tags                = { Name = "${var.project_name}-ssm-endpoint" }
      }
      ssmmessages = {
        service             = "ssmmessages"
        private_dns_enabled = true
        tags                = { Name = "${var.project_name}-ssmmessages-endpoint" }
      }
      ec2messages = {
        service             = "ec2messages"
        private_dns_enabled = true
        tags                = { Name = "${var.project_name}-ec2messages-endpoint" }
      }
    } : {},
    var.enable_ecr_cw_endpoints ? {
      ecr_api = {
        service             = "ecr.api"
        private_dns_enabled = true
        tags                = { Name = "${var.project_name}-ecr-api-endpoint" }
      }
      ecr_dkr = {
        service             = "ecr.dkr"
        private_dns_enabled = true
        tags                = { Name = "${var.project_name}-ecr-dkr-endpoint" }
      }
      logs = {
        service             = "logs"
        private_dns_enabled = true
        tags                = { Name = "${var.project_name}-logs-endpoint" }
      }
    } : {},
    var.enable_monitoring_endpoint ? {
      monitoring = {
        service             = "monitoring"
        private_dns_enabled = true
        tags                = { Name = "${var.project_name}-monitoring-endpoint" }
      }
    } : {},
    var.enable_sts_endpoint ? {
      sts = {
        service             = "sts"
        private_dns_enabled = true
        tags                = { Name = "${var.project_name}-sts-endpoint" }
      }
    } : {},
    var.enable_ec2_endpoint ? {
      ec2 = {
        service             = "ec2"
        private_dns_enabled = true
        tags                = { Name = "${var.project_name}-ec2-endpoint" }
      }
    } : {},
    var.enable_sqs_endpoint ? {
      sqs = {
        service             = "sqs"
        private_dns_enabled = true
        tags                = { Name = "${var.project_name}-sqs-endpoint" }
      }
    } : {},
    var.enable_eks_endpoint ? {
      eks = {
        service             = "eks"
        private_dns_enabled = true
        tags                = { Name = "${var.project_name}-eks-endpoint" }
      }
    } : {},
    var.enable_s3_endpoint ? {
      s3 = {
        service         = "s3"
        service_type    = "Gateway"
        policy          = data.aws_iam_policy_document.s3_gateway_allow_get_any.json
        route_table_ids = length(var.s3_route_table_ids) > 0 ? var.s3_route_table_ids : module.vpc_core.private_route_table_ids
        tags            = { Name = "${var.project_name}-s3-endpoint" }
      }
    } : {}
  )

  vpce_sg_rules = {
    for cidr in local.vpce_ingress_cidrs :
    "ingress_https_${replace(cidr, "/", "_")}" => {
      description = "HTTPS from ${cidr}"
      cidr_blocks = [cidr]
    }
  }
}

module "vpc_core" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.0"

  name = var.vpc_name
  cidr = var.vpc_cidr

  azs             = local.azs
  public_subnets  = [var.pub_subnet_1a_cidr, var.pub_subnet_2b_cidr]
  private_subnets = [var.pri_subnet_3a_cidr, var.pri_subnet_4b_cidr]

  public_subnet_names  = [var.pub_subnet_1a_name, var.pub_subnet_2b_name]
  private_subnet_names = [var.pri_subnet_3a_name, var.pri_subnet_4b_name]

  enable_dns_hostnames = true
  enable_dns_support   = true

  enable_nat_gateway = var.enable_nat_gateway
  single_nat_gateway = var.single_nat_gateway

  enable_flow_log                                 = var.enable_vpc_flow_logs
  flow_log_destination_type                       = "cloud-watch-logs"
  create_flow_log_cloudwatch_log_group            = true
  create_flow_log_cloudwatch_iam_role             = true
  flow_log_cloudwatch_log_group_retention_in_days = var.vpc_flow_logs_retention_days
  flow_log_traffic_type                           = var.vpc_flow_logs_traffic_type
  flow_log_max_aggregation_interval               = 60

  public_subnet_tags = merge(
    {
      "kubernetes.io/cluster/${var.project_name}" = "shared"
      "kubernetes.io/role/elb"                    = 1
    },
    var.karpenter_allow_public_subnets ? { "karpenter.sh/discovery" = var.project_name } : {}
  )

  private_subnet_tags = {
    "kubernetes.io/cluster/${var.project_name}" = "shared"
    "kubernetes.io/role/internal-elb"           = 1
    "karpenter.sh/discovery"                    = var.project_name
  }

  tags = { Project = var.project_name }
}

module "vpc_endpoints" {
  source  = "terraform-aws-modules/vpc/aws//modules/vpc-endpoints"
  version = "~> 6.0"

  create = length(local.endpoints_map) > 0

  vpc_id    = module.vpc_core.vpc_id
  endpoints = local.endpoints_map

  create_security_group      = local.any_interface_endpoints
  security_group_name_prefix = "${var.project_name}-vpce-"
  security_group_description = "VPC endpoint security group"
  security_group_rules       = local.vpce_sg_rules

  subnet_ids = local.any_interface_endpoints ? module.vpc_core.private_subnets : null

  tags = { Project = var.project_name }
}

resource "aws_security_group" "bastion" {
  count       = var.enable_bastion ? 1 : 0
  name        = "${var.project_name}-bastion-sg"
  description = "Bastion host SG (rules managed separately)"
  vpc_id      = module.vpc_core.vpc_id
  tags        = { Name = "${var.project_name}-bastion-sg" }
}

resource "aws_vpc_security_group_egress_rule" "bastion_all_egress" {
  count             = var.enable_bastion ? 1 : 0
  security_group_id = aws_security_group.bastion[0].id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
  description       = "Allow all egress"
}

resource "aws_vpc_security_group_ingress_rule" "bastion_ssh" {
  count             = var.enable_bastion ? 1 : 0
  security_group_id = aws_security_group.bastion[0].id
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
  cidr_ipv4         = var.allowed_ssh_cidr
  description       = "SSH from allowed CIDR"
}

resource "aws_security_group" "ec2_default" {
  name        = var.security_group_name
  description = "Default SG for admin EC2"
  vpc_id      = module.vpc_core.vpc_id
  tags        = { Name = var.security_group_name }
}

resource "aws_vpc_security_group_egress_rule" "ec2_default_all_egress" {
  security_group_id = aws_security_group.ec2_default.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
  description       = "Allow all egress"
}

resource "aws_vpc_security_group_ingress_rule" "ec2_default_ssh_from_bastion" {
  count                        = var.enable_bastion ? 1 : 0
  security_group_id            = aws_security_group.ec2_default.id
  from_port                    = 22
  to_port                      = 22
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.bastion[0].id
  description                  = "SSH from Bastion host SG"
}

resource "aws_vpc_security_group_ingress_rule" "vpce_allow_from_admin_ec2_https" {
  count                        = local.any_interface_endpoints ? 1 : 0
  security_group_id            = module.vpc_endpoints.security_group_id
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.ec2_default.id
  description                  = "HTTPS from admin EC2 SG"
}
