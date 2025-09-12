locals {
  cluster_name = var.project_name
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.1"

  name                                     = local.cluster_name
  kubernetes_version                       = var.k8s_version
  vpc_id                                   = var.vpc_id
  subnet_ids                               = var.subnet_ids

  endpoint_public_access                   = false
  endpoint_private_access                  = true

  create_iam_role                          = false
  iam_role_arn                             = var.eks_cluster_role_arn

  authentication_mode                      = "API"
  enable_cluster_creator_admin_permissions = true

  enabled_log_types                        = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  create_kms_key                           = true
  kms_key_enable_default_policy            = true
  encryption_config = {
  
    resources = ["secrets"]

  }

  enable_irsa                              = true

  node_security_group_additional_rules = {
    intra_node_all = {
      description = "Allow all node-to-node traffic "
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "ingress"
      self        = true
    }
  }

  tags = { Name = "${local.cluster_name}-eks-cluster" }
}

resource "aws_ec2_tag" "karpenter_discovery_node_sg" {
  resource_id = module.eks.node_security_group_id
  key         = "karpenter.sh/discovery"
  value       = local.cluster_name
}

resource "aws_ec2_tag" "karpenter_discovery_cluster_sg" {
  resource_id = module.eks.cluster_security_group_id
  key         = "karpenter.sh/discovery"
  value       = local.cluster_name
}

resource "aws_eks_access_entry" "admin_ec2" {
  cluster_name  = module.eks.cluster_name
  principal_arn = var.admin_role_arn
  type          = "STANDARD"
  depends_on    = [module.eks]
}

resource "aws_eks_access_policy_association" "admin_ec2_cluster_admin" {
  cluster_name  = module.eks.cluster_name
  principal_arn = var.admin_role_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.admin_ec2]
}

resource "aws_vpc_security_group_ingress_rule" "eks_api_from_admin_ec2" {
  security_group_id            = module.eks.cluster_security_group_id
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "tcp"
  referenced_security_group_id = var.admin_ec2_sg_id
  description                  = "Allow admin EC2 to reach EKS API server on 443"
}

resource "aws_vpc_security_group_ingress_rule" "vpce_allow_from_nodes_https" {
  count                        = var.create_vpce_nodes_https_rule ? 1 : 0
  security_group_id            = var.vpce_sg_id
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "tcp"
  referenced_security_group_id = module.eks.node_security_group_id
  description                  = "HTTPS from nodes SG"
  depends_on                   = [module.eks]
}
