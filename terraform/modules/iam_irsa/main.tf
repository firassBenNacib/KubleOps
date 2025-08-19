module "alb_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.59.0"

  create_role = true
  role_name   = "AmazonEKSLoadBalancerControllerRole"

  attach_load_balancer_controller_policy = true

  oidc_providers = {
    eks = {
      provider_arn               = var.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }
}

resource "aws_iam_policy" "alb_additional_permissions" {
  name        = "${var.project_name}-alb-extra-policy"
  description = "Extra ALB permissions required by AWS Load Balancer Controller"
  policy      = file("${path.module}/policies/aws_lb_controller_policy.json")

  tags = {
    Name = "${var.project_name}-alb-extra-policy"
  }
}

resource "aws_iam_role_policy_attachment" "alb_additional_permissions_attach" {
  role       = module.alb_irsa_role.iam_role_name
  policy_arn = aws_iam_policy.alb_additional_permissions.arn
}

module "ecr_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.59.0"

  create_role = true
  role_name   = "${var.project_name}-ecr-access-role"

  role_policy_arns = {
    ECRReadOnly = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  }

  oidc_providers = {
    eks = {
      provider_arn = var.oidc_provider_arn
      namespace_service_accounts = [
        "backend:backend-service-account",
        "frontend:frontend-service-account"
      ]
    }
  }
}

module "ebs_csi_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.59.0"

  role_name             = "${var.project_name}-ebs-csi-controller-role"
  attach_ebs_csi_policy = true

  oidc_providers = {
    main = {
      provider_arn               = var.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }
}

resource "aws_iam_policy" "external_dns_route53" {
  name        = "${var.project_name}-ExternalDNS-Route53"
  description = "Allow ExternalDNS to manage DNS records in a specific hosted zone"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = ["route53:ChangeResourceRecordSets"],
        Resource = "arn:aws:route53:::hostedzone/${var.route53_zone_id}"
      },
      {
        Effect = "Allow",
        Action = [
          "route53:ListHostedZones",
          "route53:ListResourceRecordSets",
          "route53:ListTagsForResource",
          "route53:GetHostedZone"
        ],
        Resource = "*"
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-ExternalDNS-Route53"
  }
}

module "external_dns_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.59.0"

  create_role = true
  role_name   = "${var.project_name}-external-dns-role"

  role_policy_arns = {
    Route53 = aws_iam_policy.external_dns_route53.arn
  }

  oidc_providers = {
    eks = {
      provider_arn               = var.oidc_provider_arn
      namespace_service_accounts = ["external-dns:external-dns"]
    }
  }
}

resource "aws_iam_policy" "fluent_bit_cw" {
  name        = "${var.project_name}-FluentBitCloudWatch"
  description = "Fluent Bit -> CloudWatch Logs and metrics"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams",
          "logs:PutRetentionPolicy"
        ],
        Resource = "*"
      },
      {
        Effect   = "Allow",
        Action   = ["cloudwatch:PutMetricData"],
        Resource = "*"
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-FluentBitCloudWatch"
  }
}

module "fluent_bit_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.59.0"

  create_role = true
  role_name   = "${var.project_name}-fluent-bit"

  role_policy_arns = {
    CloudWatch = aws_iam_policy.fluent_bit_cw.arn
  }

  oidc_providers = {
    eks = {
      provider_arn               = var.oidc_provider_arn
      namespace_service_accounts = ["amazon-cloudwatch:fluent-bit"]
    }
  }
}

module "cw_agent_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.59.0"

  create_role      = true
  role_name        = "${var.project_name}-cloudwatch-agent"
  role_policy_arns = { cwAgent = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy" }

  oidc_providers = {
    eks = {
      provider_arn               = var.oidc_provider_arn
      namespace_service_accounts = ["amazon-cloudwatch:cloudwatch-agent"]
    }
  }
}

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_region" "current" {}

resource "aws_iam_policy" "karpenter_controller" {
  name        = "${var.project_name}-KarpenterControllerPolicy"
  description = "Permissions for Karpenter controller to manage capacity"
  policy = templatefile("${path.module}/policies/karpenter-controller.json", {
    Partition                     = data.aws_partition.current.partition
    Region                        = data.aws_region.current.name
    AccountId                     = data.aws_caller_identity.current.account_id
    ClusterName                   = var.project_name
    KarpenterInterruptionQueueArn = var.karpenter_interruption_queue_arn
    KarpenterNodeRoleArn          = var.karpenter_node_role_arn
  })

  tags = {
    Name = "${var.project_name}-KarpenterControllerPolicy"
  }
}

module "karpenter_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.59.0"

  create_role = true
  role_name   = "${var.project_name}-karpenter"

  role_policy_arns = {
    Controller = aws_iam_policy.karpenter_controller.arn
  }

  oidc_providers = {
    eks = {
      provider_arn               = var.oidc_provider_arn
      namespace_service_accounts = ["kube-system:karpenter"]
    }
  }
}
