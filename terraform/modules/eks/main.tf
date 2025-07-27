resource "aws_eks_cluster" "eks_cluster" {
  name     = var.project_name
  role_arn = var.eks_cluster_role_arn
  version  = var.k8s_version

  vpc_config {
    endpoint_private_access = false
    endpoint_public_access  = true
    subnet_ids = [
      var.pub_subnet_1a_id,
      var.pub_subnet_2b_id,
      var.pri_subnet_3a_id,
      var.pri_subnet_4b_id
    ]
  }

  access_config {
    authentication_mode                         = "API"
    bootstrap_cluster_creator_admin_permissions = true
  }

  tags = {
    Name = "${var.project_name}-eks-cluster"
  }

  depends_on = [var.eks_cluster_role_arn]
}
