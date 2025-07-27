resource "aws_eks_node_group" "node_group" {
  cluster_name    = var.eks_cluster_name
  node_group_name = "${var.eks_cluster_name}-node-group"
  node_role_arn   = var.node_group_role_arn

  subnet_ids = [
    var.pri_subnet_3a_id,
    var.pri_subnet_4b_id
  ]

  scaling_config {
    desired_size = var.desired_size
    max_size     = var.max_size
    min_size     = var.min_size
  }

  ami_type       = "AL2023_x86_64_STANDARD"
  capacity_type  = "ON_DEMAND"
  disk_size      = var.disk_size
  instance_types = [var.node_group_instance_type]
  version        = var.k8s_version

  labels = {
    role = "${var.eks_cluster_name}-node-group-role"
    name = "${var.eks_cluster_name}-node-group"
  }

  tags = {
    Name = "${var.eks_cluster_name}-node-group"
  }
}
