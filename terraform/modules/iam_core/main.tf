data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

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
    Name    = var.iam_role_name
    Project = var.project_name
  }
}

resource "aws_iam_policy" "sts_access" {
  name        = "${var.project_name}-STSAccess"
  description = "Allow getting caller identity"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect   = "Allow",
      Action   = ["sts:GetCallerIdentity"],
      Resource = "*"
    }]
  })
}

resource "aws_iam_policy" "ecr_access_policy" {
  name        = "${var.project_name}-ECRAccessPolicy"
  description = "Allow EC2 to access ECR with least privilege"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = ["ecr:GetAuthorizationToken"],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetRepositoryPolicy",
          "ecr:ListImages",
          "ecr:BatchGetImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage"
        ],
        Resource = [
          "arn:aws:ecr:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:repository/${var.project_name}/*",
          "arn:aws:ecr:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:repository/backend",
          "arn:aws:ecr:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:repository/frontend"
        ]
      }
    ]
  })
}

resource "aws_iam_policy" "ec2_enhanced_access" {
  name        = "${var.project_name}-EC2EnhancedAccess"
  description = "Enhanced EC2 read-only access for infrastructure information"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceStatus",
          "ec2:DescribeImages",
          "ec2:DescribeKeyPairs",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSubnets",
          "ec2:DescribeVpcs",
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeRegions",
          "ec2:DescribeRouteTables",
          "ec2:DescribeInternetGateways",
          "ec2:DescribeNetworkInterfaces"
        ],
        Resource = "*"
      },
      {
        Effect   = "Allow",
        Action   = ["ec2:CreateTags"],
        Resource = "*",
        Condition = {
          StringEquals = {
            "aws:RequestedRegion" : data.aws_region.current.name
          }
        }
      }
    ]
  })
}

resource "aws_iam_policy" "eks_update_kubeconfig_access" {
  name        = "${var.project_name}-EKSUpdateKubeconfigAccess"
  description = "Allow EC2 to call EKS operations for kubeconfig"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect   = "Allow",
      Action   = ["eks:DescribeCluster", "eks:ListClusters"],
      Resource = "arn:aws:eks:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:cluster/${var.project_name}"
    }]
  })
}

resource "aws_iam_policy" "ssm_limited_access" {
  name        = "${var.project_name}-SSMLimitedAccess"
  description = "Limited SSM access for project parameters"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect   = "Allow",
      Action   = ["ssm:GetParameter", "ssm:GetParameters", "ssm:GetParameterHistory"],
      Resource = "arn:aws:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:parameter/${var.project_name}/*"
    }]
  })
}

resource "aws_iam_policy" "eks_describe" {
  name        = "${var.project_name}-EKSDescribe"
  description = "Allow EKS Describe/List actions for this cluster"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Action = [
        "eks:DescribeCluster",
        "eks:ListClusters",
        "eks:ListUpdates",
        "eks:DescribeUpdate",
        "eks:ListNodegroups",
        "eks:DescribeNodegroup",
        "eks:ListAddons",
        "eks:DescribeAddon",
        "eks:DescribeAddonVersions",
        "eks:ListAddonVersions"
      ],
      Resource = [
        "arn:aws:eks:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:cluster/${var.project_name}",
        "arn:aws:eks:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:nodegroup/${var.project_name}/*"
      ]
    }]
  })
}

resource "aws_iam_policy" "iam_limited_access" {
  name        = "${var.project_name}-IAMLimitedAccess"
  description = "Very limited IAM access for service account management"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = ["iam:GetRole", "iam:PassRole"],
        Resource = [
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.project_name}-*",
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/AmazonEKSLoadBalancerControllerRole",
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/KarpenterNodeRole-${var.project_name}"
        ]
      },
      {
        Effect   = "Allow",
        Action   = ["iam:GetServiceLinkedRoleDeletionStatus", "iam:CreateServiceLinkedRole"],
        Resource = "*",
        Condition = {
          StringEquals = {
            "iam:AWSServiceName" : [
              "elasticloadbalancing.amazonaws.com",
              "eks.amazonaws.com"
            ]
          }
        }
      }
    ]
  })
}

resource "aws_iam_policy" "acm_readonly_limited" {
  name        = "${var.project_name}-ACMReadOnlyLimited"
  description = "Allow listing/reading ACM certs"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      { Effect = "Allow", Action = ["acm:ListCertificates"], Resource = "*" },
      { Effect = "Allow", Action = ["acm:DescribeCertificate", "acm:GetCertificate"], Resource = "*" }
    ]
  })
}

resource "aws_iam_policy" "eks_access_entries_admin" {
  name        = "${var.project_name}-EKSAccessEntries"
  description = "Allow EC2 host to manage EKS access entries for this cluster"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Action = [
        "eks:CreateAccessEntry",
        "eks:DescribeAccessEntry",
        "eks:ListAccessEntries",
        "eks:AssociateAccessPolicy",
        "eks:DisassociateAccessPolicy",
        "eks:DeleteAccessEntry"
      ],
      Resource = [
        "arn:aws:eks:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:cluster/${var.project_name}",
        "arn:aws:eks:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:access-entry/${var.project_name}/*"
      ]
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ec2_ssm_core" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "ec2_sts_access" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.sts_access.arn
}

resource "aws_iam_role_policy_attachment" "ecr_policy_attachment" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.ecr_access_policy.arn
}

resource "aws_iam_role_policy_attachment" "ec2_enhanced_access" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.ec2_enhanced_access.arn
}

resource "aws_iam_role_policy_attachment" "eks_kubeconfig_access_attach" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.eks_update_kubeconfig_access.arn
}

resource "aws_iam_role_policy_attachment" "eks_describe_attach" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.eks_describe.arn
}

resource "aws_iam_role_policy_attachment" "ssm_limited_access_attach" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.ssm_limited_access.arn
}

resource "aws_iam_role_policy_attachment" "iam_limited_access_attach" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.iam_limited_access.arn
}

resource "aws_iam_role_policy_attachment" "ec2_acm_readonly_attach" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.acm_readonly_limited.arn
}

resource "aws_iam_role_policy_attachment" "eks_access_entries_admin_attach" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.eks_access_entries_admin.arn
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
    Name    = "${var.project_name}-eks-cluster-role"
    Project = var.project_name
  }
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_policy" "eks_elb_limited" {
  name        = "${var.project_name}-EKSELBLimited"
  description = "Limited ELB/EC2 describes for EKS cluster"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Action = [
        "elasticloadbalancing:DescribeLoadBalancers",
        "elasticloadbalancing:DescribeLoadBalancerAttributes",
        "elasticloadbalancing:DescribeListeners",
        "elasticloadbalancing:DescribeTargetGroups",
        "elasticloadbalancing:DescribeTargetHealth",
        "elasticloadbalancing:DescribeTags",
        "ec2:DescribeAccountAttributes",
        "ec2:DescribeAddresses",
        "ec2:DescribeInternetGateways",
        "ec2:DescribeVpcs",
        "ec2:DescribeSubnets",
        "ec2:DescribeSecurityGroups",
        "ec2:DescribeInstances",
        "ec2:DescribeNetworkInterfaces"
      ],
      Resource = "*"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_elb_limited_policy" {
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = aws_iam_policy.eks_elb_limited.arn
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
    Name    = "${var.project_name}-node-group-role"
    Project = var.project_name
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
