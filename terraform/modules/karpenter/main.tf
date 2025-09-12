locals {
  cluster_name = var.cluster_name
  ssm_prefix   = var.ssm_prefix != "" ? var.ssm_prefix : "/${var.cluster_name}"
}

module "eks_karpenter" {
  source  = "terraform-aws-modules/eks/aws//modules/karpenter"
  version = "~> 21.1"

  cluster_name                      = local.cluster_name
  region                            = var.region
  create_node_iam_role              = true
  create_access_entry               = true
  enable_spot_termination           = true
  create_instance_profile           = true
  node_iam_role_attach_cni_policy   = true
  node_iam_role_additional_policies = { AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore" }
  iam_role_name                     = "KarpenterController-${local.cluster_name}"
  node_iam_role_name                = "KarpenterNodeRole-${local.cluster_name}"

  tags = var.tags
}

resource "aws_ssm_parameter" "karpenter_controller_role_arn" {
  name  = "${local.ssm_prefix}/karpenter/controller_role_arn"
  type  = "String"
  value = module.eks_karpenter.iam_role_arn
}

resource "aws_ssm_parameter" "karpenter_node_role_arn" {
  name  = "${local.ssm_prefix}/karpenter/node_role_arn"
  type  = "String"
  value = module.eks_karpenter.node_iam_role_arn
}

resource "aws_ssm_parameter" "karpenter_queue_name" {
  name  = "${local.ssm_prefix}/karpenter/queue_name"
  type  = "String"
  value = module.eks_karpenter.queue_name
}

resource "aws_eks_pod_identity_association" "karpenter_controller" {
  cluster_name    = local.cluster_name
  namespace       = "karpenter"
  service_account = "karpenter"
  role_arn        = module.eks_karpenter.iam_role_arn
  depends_on      = [module.eks_karpenter]
}
