module "vpc" {
  source           = "./modules/vpc"
  region           = var.region
  project_name     = var.project_name
  allowed_ssh_cidr = var.allowed_ssh_cidr

  vpc_cidr           = var.vpc_cidr
  pub_subnet_1a_cidr = var.pub_subnet_1a_cidr
  pub_subnet_2b_cidr = var.pub_subnet_2b_cidr
  pri_subnet_3a_cidr = var.pri_subnet_3a_cidr
  pri_subnet_4b_cidr = var.pri_subnet_4b_cidr

  vpc_name            = var.vpc_name
  igw_name            = var.igw_name
  route_table_name    = var.route_table_name
  security_group_name = var.security_group_name

  pub_subnet_1a_name = var.pub_subnet_1a_name
  pub_subnet_2b_name = var.pub_subnet_2b_name
  pri_subnet_3a_name = var.pri_subnet_3a_name
  pri_subnet_4b_name = var.pri_subnet_4b_name

  enable_bastion             = var.enable_bastion
  enable_ssm_endpoints       = var.enable_ssm_endpoints
  enable_ecr_cw_endpoints    = var.enable_ecr_cw_endpoints
  enable_monitoring_endpoint = var.enable_monitoring_endpoint
  enable_sts_endpoint        = var.enable_sts_endpoint
  enable_ec2_endpoint        = var.enable_ec2_endpoint
  enable_sqs_endpoint        = var.enable_sqs_endpoint
  enable_eks_endpoint        = var.enable_eks_endpoint
  enable_s3_endpoint         = var.enable_s3_endpoint

  endpoints_allowed_cidrs = var.endpoints_allowed_cidrs

  s3_route_table_ids = []
}

module "nat_gw" {
  source           = "./modules/nat-gw"
  vpc_id           = module.vpc.vpc_id
  igw_id           = module.vpc.igw_id
  pub_subnet_1a_id = module.vpc.pub_subnet_1a_id
  pub_subnet_2b_id = module.vpc.pub_subnet_2b_id
  pri_subnet_3a_id = module.vpc.pri_subnet_3a_id
  pri_subnet_4b_id = module.vpc.pri_subnet_4b_id
}

module "route53_zone" {
  source       = "./modules/route53-zone"
  zone_name    = var.zone_name
  private_zone = false
}

module "acm" {
  source          = "./modules/acm"
  domain_name     = var.acm_domain_name
  route53_zone_id = module.route53_zone.zone_id
  tags            = { Name = "${var.project_name}-alb-cert" }
}

module "iam_core" {
  source        = "./modules/iam_core"
  project_name  = var.project_name
  iam_role_name = var.iam_role_name
}

module "eks" {
  source               = "./modules/eks"
  project_name         = var.project_name
  k8s_version          = var.k8s_version
  eks_cluster_role_arn = module.iam_core.eks_cluster_role_arn

  pub_subnet_1a_id = module.vpc.pub_subnet_1a_id
  pub_subnet_2b_id = module.vpc.pub_subnet_2b_id
  pri_subnet_3a_id = module.vpc.pri_subnet_3a_id
  pri_subnet_4b_id = module.vpc.pri_subnet_4b_id
}

module "eks_oidc" {
  source       = "./modules/eks_oidc"
  eks_oidc_url = module.eks.oidc_provider_url
  depends_on   = [module.eks]
}

module "karpenter" {
  source                  = "./modules/karpenter"
  project_name            = var.project_name
  queue_retention_seconds = var.queue_retention_seconds
  dlq_max_receive_count   = var.dlq_max_receive_count
}

module "iam_irsa" {
  source                           = "./modules/iam_irsa"
  project_name                     = var.project_name
  oidc_provider_arn                = module.eks_oidc.oidc_provider_arn
  route53_zone_id                  = module.route53_zone.zone_id
  karpenter_node_role_arn          = module.karpenter.karpenter_node_role_arn
  karpenter_interruption_queue_arn = module.karpenter.karpenter_interruption_queue_arn
}

module "node_group" {
  source                   = "./modules/node-group"
  eks_cluster_name         = module.eks.eks_cluster_name
  node_group_role_arn      = module.iam_core.node_group_role_arn
  pri_subnet_3a_id         = module.vpc.pri_subnet_3a_id
  pri_subnet_4b_id         = module.vpc.pri_subnet_4b_id
  node_group_instance_type = var.node_group_instance_type
  disk_size                = 20
  desired_size             = 2
  min_size                 = 2
  max_size                 = 10
  k8s_version              = var.k8s_version
  depends_on               = [module.eks]
}

module "ec2" {
  source                = "./modules/ec2"
  instance_type         = var.instance_type
  instance_name         = var.instance_name
  key_name              = var.key_name
  subnet_id             = module.vpc.pri_subnet_3a_id
  security_group_id     = module.vpc.sg_id
  iam_role_name         = module.iam_core.ec2_role_name
  instance_profile_name = "KubleOps-server-server-instance-profile"
  volume_size           = 20
  depends_on            = [module.eks, module.node_group, module.iam_core]
}

module "bastion" {
  count                 = var.enable_bastion ? 1 : 0
  source                = "./modules/bastion"
  bastion_instance_type = var.bastion_instance_type
  bastion_instance_name = var.bastion_name
  key_name              = var.key_name
  subnet_id             = module.vpc.pub_subnet_1a_id
  security_group_id     = module.vpc.bastion_sg_id
}
