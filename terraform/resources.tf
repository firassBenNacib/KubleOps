data "aws_region" "current" {}

resource "aws_eks_addon" "ebs_csi" {
  cluster_name                = module.eks.eks_cluster_name
  addon_name                  = "aws-ebs-csi-driver"
  service_account_role_arn    = module.iam_irsa.ebs_csi_role_arn
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
}

resource "aws_eks_addon" "coredns" {
  cluster_name                = module.eks.eks_cluster_name
  addon_name                  = "coredns"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name                = module.eks.eks_cluster_name
  addon_name                  = "kube-proxy"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
}

resource "aws_eks_addon" "vpc_cni" {
  count                       = var.enable_network_policy ? 1 : 0
  cluster_name                = module.eks.eks_cluster_name
  addon_name                  = "vpc-cni"
  configuration_values        = jsonencode({ enableNetworkPolicy = "true" })
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
}

resource "aws_eks_addon" "metrics_server" {
  cluster_name                = module.eks.eks_cluster_name
  addon_name                  = "metrics-server"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
}

resource "aws_eks_addon" "fluent_bit" {
  cluster_name                = module.eks.eks_cluster_name
  addon_name                  = "fluent-bit"
  service_account_role_arn    = module.iam_irsa.fluent_bit_role_arn
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
}

resource "aws_eks_addon" "kube_state_metrics" {
  cluster_name                = module.eks.eks_cluster_name
  addon_name                  = "kube-state-metrics"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
}

resource "aws_eks_addon" "node_exporter" {
  cluster_name                = module.eks.eks_cluster_name
  addon_name                  = "prometheus-node-exporter"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
}

resource "aws_eks_access_entry" "ec2_role_entry" {
  cluster_name  = module.eks.eks_cluster_name
  principal_arn = module.iam_core.ec2_role_arn
}

resource "aws_eks_access_policy_association" "ec2_role_cluster_admin" {
  cluster_name  = module.eks.eks_cluster_name
  principal_arn = aws_eks_access_entry.ec2_role_entry.principal_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  access_scope { type = "cluster" }
}

resource "aws_ssm_parameter" "acm_arn" {
  name  = "/KubleOps/acm_arn"
  type  = "String"
  value = module.acm.certificate_arn
}

resource "aws_security_group_rule" "allow_admin_to_eks_api" {
  description              = "Allow admin EC2 SG to reach EKS private API (443)"
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = module.eks.cluster_security_group_id
  source_security_group_id = module.vpc.sg_id
}

resource "aws_ec2_tag" "csg_karpenter_discovery" {
  resource_id = module.eks.cluster_security_group_id
  key         = "karpenter.sh/discovery"
  value       = var.project_name
}

resource "aws_eks_access_entry" "karpenter_node_role" {
  cluster_name  = module.eks.eks_cluster_name
  principal_arn = module.karpenter.karpenter_node_role_arn
  type          = "EC2_LINUX"
}
