locals {
  common = {
    resolve_conflicts_on_create = "OVERWRITE"
    resolve_conflicts_on_update = "OVERWRITE"
    tags                        = var.tags
  }
}

resource "aws_eks_addon" "vpc_cni" {
  cluster_name = var.cluster_name
  addon_name   = "vpc-cni"

  configuration_values = jsonencode({
    enableNetworkPolicy = var.enable_network_policy ? "true" : "false"
    env = {
      ENABLE_PREFIX_DELEGATION = "true"
      WARM_PREFIX_TARGET       = "1"
      MINIMUM_IP_TARGET        = "1"
    }
  })

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  tags                        = local.common.tags
}


resource "aws_eks_addon" "coredns" {
  cluster_name                = var.cluster_name
  addon_name                  = "coredns"
  resolve_conflicts_on_create = local.common.resolve_conflicts_on_create
  resolve_conflicts_on_update = local.common.resolve_conflicts_on_update
  tags                        = local.common.tags
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name                = var.cluster_name
  addon_name                  = "kube-proxy"
  resolve_conflicts_on_create = local.common.resolve_conflicts_on_create
  resolve_conflicts_on_update = local.common.resolve_conflicts_on_update
  tags                        = local.common.tags
}

resource "aws_eks_addon" "ebs_csi" {
  cluster_name                = var.cluster_name
  addon_name                  = "aws-ebs-csi-driver"
  service_account_role_arn    = var.ebs_csi_role_arn
  resolve_conflicts_on_create = local.common.resolve_conflicts_on_create
  resolve_conflicts_on_update = local.common.resolve_conflicts_on_update
  tags                        = local.common.tags
}

resource "aws_eks_addon" "pod_identity" {
  cluster_name                = var.cluster_name
  addon_name                  = "eks-pod-identity-agent"
  resolve_conflicts_on_create = local.common.resolve_conflicts_on_create
  resolve_conflicts_on_update = local.common.resolve_conflicts_on_update
  tags                        = local.common.tags
}

resource "aws_eks_addon" "metrics_server" {
  cluster_name                = var.cluster_name
  addon_name                  = "metrics-server"
  resolve_conflicts_on_create = local.common.resolve_conflicts_on_create
  resolve_conflicts_on_update = local.common.resolve_conflicts_on_update
  tags                        = local.common.tags
}

resource "aws_eks_addon" "fluent_bit" {
  cluster_name                = var.cluster_name
  addon_name                  = "fluent-bit"
  resolve_conflicts_on_create = local.common.resolve_conflicts_on_create
  resolve_conflicts_on_update = local.common.resolve_conflicts_on_update
  tags                        = local.common.tags
}
