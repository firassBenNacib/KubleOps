data "aws_iam_policy_document" "ec2_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ec2_role" {
  name               = var.iam_role_name
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role_policy.json

  tags = {
    Name = var.iam_role_name
  }
}

resource "aws_iam_policy" "ecr_access_policy" {
  name        = "ECRAccessPolicy"
  description = "Allow EC2 to access ECR"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect   = "Allow",
      Action   = [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetRepositoryPolicy",
        "ecr:ListImages",
        "ecr:BatchGetImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload",
        "ecr:PutImage"
      ],
      Resource = "*"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecr_policy_attachment" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.ecr_access_policy.arn
}

resource "aws_iam_policy" "eks_update_kubeconfig_access" {
  name        = "EKSUpdateKubeconfigAccess"
  description = "Allow EC2 to call EKS Describe for kubeconfig"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = ["eks:DescribeCluster"],
        Resource = "*"
      },
      {
        Effect   = "Allow",
        Action   = ["ssm:GetParameter", "ssm:GetParameters", "ssm:GetParameterHistory"],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "eks_kubeconfig_access_attach" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.eks_update_kubeconfig_access.arn
}

resource "aws_iam_policy" "eks_describe_versions" {
  name        = "EksDescribeClusterVersions"
  description = "Allow EKS Describe & List actions"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect   = "Allow",
      Action   = [
        "eks:DescribeClusterVersions",
        "eks:DescribeCluster",
        "eks:ListClusters",
        "eks:ListUpdates",
        "eks:DescribeUpdate",
        "eks:ListNodegroups",
        "eks:DescribeNodegroup"
      ],
      Resource = "*"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_describe_versions_attach" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.eks_describe_versions.arn
}

locals {
  ec2_managed_policies = [
    "arn:aws:iam::aws:policy/AmazonVPCFullAccess",
    "arn:aws:iam::aws:policy/AWSCloudFormationFullAccess",
    "arn:aws:iam::aws:policy/IAMFullAccess",
    "arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  ]
}

resource "aws_iam_role_policy_attachment" "ec2_managed_policies_attach" {
  for_each   = toset(local.ec2_managed_policies)
  role       = aws_iam_role.ec2_role.name
  policy_arn = each.key
}

data "aws_iam_policy_document" "eks_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "eks_cluster_role" {
  name               = "${var.project_name}-eks-cluster-role"
  assume_role_policy = data.aws_iam_policy_document.eks_assume_role_policy.json

  tags = {
    Name = "${var.project_name}-eks-cluster-role"
  }
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role_policy_attachment" "eks_elb_policy" {
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/ElasticLoadBalancingFullAccess"
}

data "aws_iam_policy_document" "node_group_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "node_group_role" {
  name               = "${var.project_name}-node-group-role"
  assume_role_policy = data.aws_iam_policy_document.node_group_assume_role_policy.json

  tags = {
    Name = "${var.project_name}-node-group-role"
  }
}

locals {
  node_group_policies = [
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  ]
}

resource "aws_iam_role_policy_attachment" "node_group_policies" {
  for_each   = toset(local.node_group_policies)
  role       = aws_iam_role.node_group_role.name
  policy_arn = each.key
}

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

  policy = file("${path.module}/policies/aws_lb_controller_policy.json")
}

resource "aws_iam_role_policy_attachment" "alb_additional_permissions_attach" {
  role       = module.alb_irsa_role.iam_role_name
  policy_arn = aws_iam_policy.alb_additional_permissions.arn
}

module "ecr_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.30.0"

  create_role = true
  role_name   = "${var.project_name}-ecr-access-role"

  role_policy_arns = {
    ECRReadOnly = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  }

  oidc_providers = {
    eks = {
      provider_arn               = var.oidc_provider_arn
      namespace_service_accounts = [
        "backend:backend-service-account",
        "frontend:frontend-service-account"
      ]
    }
  }
}

module "ebs_csi_irsa_role" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"

  role_name                 = "${var.project_name}-ebs-csi-controller-role"
  attach_ebs_csi_policy     = true

  oidc_providers = {
    main = {
      provider_arn               = var.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }
}
