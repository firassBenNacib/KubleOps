data "aws_partition" "current" {}

data "aws_iam_role" "alb_irsa" {
  name       = "AmazonEKSLoadBalancerControllerRole"
  depends_on = [module.alb_irsa_role]
}

data "aws_iam_role" "external_dns_irsa" {
  name       = "${var.project_name}-external-dns-role"
  depends_on = [module.external_dns_irsa_role]
}

data "aws_iam_role" "ebs_csi_irsa" {
  name       = "${var.project_name}-ebs-csi-irsa"
  depends_on = [module.ebs_csi_irsa_role]
}

locals {
  partition              = data.aws_partition.current.partition
  alb_role_name          = "AmazonEKSLoadBalancerControllerRole"
  external_dns_role_name = "${var.project_name}-external-dns-role"
  ebs_csi_role_name      = "${var.project_name}-ebs-csi-irsa"
}

module "alb_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts"
  version = "~> 6.2"

  name            = local.alb_role_name
  use_name_prefix = false

  attach_load_balancer_controller_policy = true

  oidc_providers = {
    eks = {
      provider_arn               = var.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }
}

module "external_dns_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts"
  version = "~> 6.2"

  name            = local.external_dns_role_name
  use_name_prefix = false

  oidc_providers = {
    eks = {
      provider_arn               = var.oidc_provider_arn
      namespace_service_accounts = ["external-dns:external-dns"]
    }
  }
}

module "ebs_csi_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts"
  version = "~> 6.2"

  name            = local.ebs_csi_role_name
  use_name_prefix = false

  oidc_providers = {
    eks = {
      provider_arn               = var.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }
}

resource "aws_iam_policy" "external_dns_route53" {
  name        = "${var.project_name}-ExternalDNS-Route53"
  description = "Allow ExternalDNS to change records in the specified hosted zone"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = ["route53:ChangeResourceRecordSets"],
        Resource = "arn:${local.partition}:route53:::hostedzone/${var.route53_zone_id}"
      },
      {
        Effect = "Allow",
        Action = [
          "route53:ListHostedZones",
          "route53:GetHostedZone",
          "route53:ListResourceRecordSets",
          "route53:ListTagsForResource"
        ],
        Resource = "*"
      }
    ]
  })
  tags = { Name = "${var.project_name}-ExternalDNS-Route53" }
}

resource "aws_iam_role_policy_attachment" "external_dns_attach" {
  role       = local.external_dns_role_name
  policy_arn = aws_iam_policy.external_dns_route53.arn
  depends_on = [module.external_dns_irsa_role]
}

resource "aws_iam_role_policy_attachment" "ebs_csi_attach_managed_policy" {
  role       = local.ebs_csi_role_name
  policy_arn = "arn:${local.partition}:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  depends_on = [module.ebs_csi_irsa_role]
}
