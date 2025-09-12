data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_region" "current" {}

data "aws_iam_role" "eks_cluster" {
  name       = "${var.project_name}-eks-cluster-role"
  depends_on = [module.eks_cluster_role]
}

data "aws_iam_role" "node_group" {
  name       = "${var.project_name}-node-group-role"
  depends_on = [module.node_group_role]
}

data "aws_iam_role" "admin" {
  name       = var.iam_role_name
  depends_on = [module.ec2_role]
}

locals {
  account_id = data.aws_caller_identity.current.account_id
  partition  = data.aws_partition.current.partition
  region     = data.aws_region.current.id
  project    = var.project_name
  admin_role = var.iam_role_name
}

module "policy_sts_access" {
  source      = "terraform-aws-modules/iam/aws//modules/iam-policy"
  version     = "~> 6.2"
  name        = "${local.project}-STSAccess"
  description = "Allow getting caller identity"
  policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [{ Effect = "Allow", Action = ["sts:GetCallerIdentity"], Resource = "*" }]
  })
}

module "policy_ecr_access" {
  source      = "terraform-aws-modules/iam/aws//modules/iam-policy"
  version     = "~> 6.2"
  name        = "${local.project}-ECRAccessPolicy"
  description = "Push/pull to your project ECR repos"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      { Effect = "Allow", Action = ["ecr:GetAuthorizationToken"], Resource = "*" },
      {
        Effect = "Allow",
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:BatchGetImage",
          "ecr:CompleteLayerUpload",
          "ecr:DescribeRepositories",
          "ecr:GetDownloadUrlForLayer",
          "ecr:GetRepositoryPolicy",
          "ecr:InitiateLayerUpload",
          "ecr:ListImages",
          "ecr:PutImage",
          "ecr:UploadLayerPart"
        ],
        Resource = [
          "arn:${local.partition}:ecr:${local.region}:${local.account_id}:repository/${local.project}/*",
          "arn:${local.partition}:ecr:${local.region}:${local.account_id}:repository/backend",
          "arn:${local.partition}:ecr:${local.region}:${local.account_id}:repository/frontend"
        ]
      }
    ]
  })
}

module "policy_eks_kubeconfig" {
  source      = "terraform-aws-modules/iam/aws//modules/iam-policy"
  version     = "~> 6.2"
  name        = "${local.project}-EKSKubeconfigAccess"
  description = "List and describe this EKS cluster so aws eks update-kubeconfig works"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      { Effect = "Allow", Action = ["eks:ListClusters"], Resource = "*" },
      {
        Effect   = "Allow",
        Action   = ["eks:DescribeCluster"],
        Resource = "arn:${local.partition}:eks:${local.region}:${local.account_id}:cluster/${local.project}"
      }
    ]
  })
}

module "policy_ssm_param_read" {
  source      = "terraform-aws-modules/iam/aws//modules/iam-policy"
  version     = "~> 6.2"
  name        = "${local.project}-SSMParamRead"
  description = "Read-only access to Parameter Store under /<project>"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = ["ssm:GetParameter", "ssm:GetParameters", "ssm:GetParametersByPath"],
        Resource = [
          "arn:${local.partition}:ssm:${local.region}:${local.account_id}:parameter/${local.project}",
          "arn:${local.partition}:ssm:${local.region}:${local.account_id}:parameter/${local.project}/*"
        ]
      }
    ]
  })
}

module "policy_bootstrap_readonly" {
  source      = "terraform-aws-modules/iam/aws//modules/iam-policy"
  version     = "~> 6.2"
  name        = "${local.project}-BootstrapReadonly"
  description = "Minimal read + required EKS access-entry ops used by the admin EC2 bootstrap script"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = ["ec2:DescribeVpcs", "ec2:DescribeSubnets", "ec2:DescribeRouteTables", "ec2:DescribeSecurityGroups", "ec2:DescribeAccountAttributes"],
        Resource = "*"
      },
      {
        Effect   = "Allow",
        Action   = ["route53:ListHostedZones", "route53:ListHostedZonesByName", "route53:GetHostedZone", "route53:ListResourceRecordSets"],
        Resource = "*"
      },
      {
        Effect   = "Allow",
        Action   = ["acm:ListCertificates"],
        Resource = "*"
      },
      {
        Effect   = "Allow",
        Action   = ["iam:GetRole"],
        Resource = "*"
      },
      {
        Effect   = "Allow",
        Action   = ["sqs:ListQueues"],
        Resource = "*"
      },
      {
        Effect   = "Allow",
        Action   = ["eks:ListAccessPolicies", "eks:ListAssociatedAccessPolicies"],
        Resource = "*"
      },
      {
        Effect   = "Allow",
        Action   = ["eks:ListAccessEntries", "eks:DescribeAccessEntry", "eks:CreateAccessEntry", "eks:UpdateAccessEntry", "eks:AssociateAccessPolicy", "eks:DisassociateAccessPolicy", "eks:DeleteAccessEntry"],
        Resource = "arn:${local.partition}:eks:${local.region}:${local.account_id}:cluster/${local.project}"
      }
    ]
  })
}

module "ec2_role" {
  source                  = "terraform-aws-modules/iam/aws//modules/iam-role"
  version                 = "~> 6.2"
  name                    = local.admin_role
  use_name_prefix         = false
  create_instance_profile = false
  trust_policy_permissions = {
    EC2Assume = { actions = ["sts:AssumeRole"], principals = [{ type = "Service", identifiers = ["ec2.amazonaws.com"] }] }
  }
  policies = {
    AmazonSSMManagedInstanceCore = "arn:${local.partition}:iam::aws:policy/AmazonSSMManagedInstanceCore"
    STSAccess                    = module.policy_sts_access.arn
    ECRAccess                    = module.policy_ecr_access.arn
    EKSKubeconfig                = module.policy_eks_kubeconfig.arn
    SSMParamRead                 = module.policy_ssm_param_read.arn
    BootstrapReadonly            = module.policy_bootstrap_readonly.arn
  }
}

module "eks_cluster_role" {
  source          = "terraform-aws-modules/iam/aws//modules/iam-role"
  version         = "~> 6.2"
  name            = "${local.project}-eks-cluster-role"
  use_name_prefix = false
  trust_policy_permissions = {
    EKSService = { actions = ["sts:AssumeRole"], principals = [{ type = "Service", identifiers = ["eks.amazonaws.com"] }] }
  }
  policies = {
    AmazonEKSClusterPolicy = "arn:${local.partition}:iam::aws:policy/AmazonEKSClusterPolicy"
  }
  tags = { Project = local.project }
}

module "node_group_role" {
  source          = "terraform-aws-modules/iam/aws//modules/iam-role"
  version         = "~> 6.2"
  name            = "${local.project}-node-group-role"
  use_name_prefix = false
  trust_policy_permissions = {
    EC2Assume = { actions = ["sts:AssumeRole"], principals = [{ type = "Service", identifiers = ["ec2.amazonaws.com"] }] }
  }
  policies = {
    AmazonEKSWorkerNodePolicy          = "arn:${local.partition}:iam::aws:policy/AmazonEKSWorkerNodePolicy"
    AmazonEKS_CNI_Policy               = "arn:${local.partition}:iam::aws:policy/AmazonEKS_CNI_Policy"
    AmazonEC2ContainerRegistryReadOnly = "arn:${local.partition}:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
    AmazonSSMManagedInstanceCore       = "arn:${local.partition}:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }
  tags = { Project = local.project }
}

resource "aws_iam_instance_profile" "admin" {
  name = "${local.admin_role}-profile"
  role = local.admin_role
}
