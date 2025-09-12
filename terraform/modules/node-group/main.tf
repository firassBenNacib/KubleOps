module "mng" {
  source  = "terraform-aws-modules/eks/aws//modules/eks-managed-node-group"
  version = "~> 21.1"

  name            = var.node_group_name
  use_name_prefix = false
  cluster_name    = var.eks_cluster_name
  create_iam_role = false
  iam_role_arn    = var.node_group_role_arn
  subnet_ids      = [var.pri_subnet_3a_id, var.pri_subnet_4b_id]

  desired_size         = var.desired_size
  min_size             = var.min_size
  max_size             = var.max_size
  ami_type             = "AL2023_x86_64_STANDARD"
  kubernetes_version   = var.k8s_version
  capacity_type        = "ON_DEMAND"
  instance_types       = [var.node_group_instance_type]
  disk_size            = var.disk_size
  cluster_service_cidr = var.cluster_service_cidr

  tags = { Name = var.node_group_name }
}
