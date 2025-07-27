resource "aws_eks_addon" "ebs_csi" {
  cluster_name             = module.eks.eks_cluster_name
  addon_name               = "aws-ebs-csi-driver"
  service_account_role_arn = module.iam.ebs_csi_irsa_role_arn

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [module.eks, module.iam]
}

resource "aws_eks_access_entry" "ec2_role_entry" {
  cluster_name  = module.eks.eks_cluster_name
  principal_arn = module.iam.ec2_role_arn

  depends_on = [module.eks]
}

resource "aws_eks_access_policy_association" "ec2_role_cluster_admin" {
  cluster_name  = module.eks.eks_cluster_name
  principal_arn = aws_eks_access_entry.ec2_role_entry.principal_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.ec2_role_entry]
}
