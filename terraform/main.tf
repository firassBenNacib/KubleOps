module "vpc" {
  source                         = "./modules/vpc"
  project_name                   = var.project_name
  allowed_ssh_cidr               = var.allowed_ssh_cidr
  vpc_cidr                       = var.vpc_cidr
  pub_subnet_1a_cidr             = var.pub_subnet_1a_cidr
  pub_subnet_2b_cidr             = var.pub_subnet_2b_cidr
  pri_subnet_3a_cidr             = var.pri_subnet_3a_cidr
  pri_subnet_4b_cidr             = var.pri_subnet_4b_cidr
  vpc_name                       = var.vpc_name
  security_group_name            = var.security_group_name
  pub_subnet_1a_name             = var.pub_subnet_1a_name
  pub_subnet_2b_name             = var.pub_subnet_2b_name
  pri_subnet_3a_name             = var.pri_subnet_3a_name
  pri_subnet_4b_name             = var.pri_subnet_4b_name
  enable_bastion                 = var.enable_bastion
  enable_ssm_endpoints           = var.enable_ssm_endpoints
  enable_ecr_cw_endpoints        = var.enable_ecr_cw_endpoints
  enable_monitoring_endpoint     = var.enable_monitoring_endpoint
  enable_sts_endpoint            = var.enable_sts_endpoint
  enable_ec2_endpoint            = var.enable_ec2_endpoint
  enable_sqs_endpoint            = var.enable_sqs_endpoint
  enable_eks_endpoint            = var.enable_eks_endpoint
  enable_s3_endpoint             = var.enable_s3_endpoint
  enable_nat_gateway             = var.enable_nat_gateway
  single_nat_gateway             = var.single_nat_gateway
  endpoints_allowed_cidrs        = var.endpoints_allowed_cidrs
  s3_route_table_ids             = var.s3_route_table_ids
  enable_vpc_flow_logs           = var.enable_vpc_flow_logs
  vpc_flow_logs_retention_days   = var.vpc_flow_logs_retention_days
  vpc_flow_logs_traffic_type     = var.vpc_flow_logs_traffic_type
  karpenter_allow_public_subnets = var.karpenter_allow_public_subnets
}

module "route53_zone" {
  source       = "./modules/route53-zone"
  zone_name    = var.zone_name
  private_zone = var.route53_private_zone
}

module "acm" {
  source                    = "./modules/acm"
  domain_name               = var.acm_domain_name
  subject_alternative_names = var.acm_subject_alternative_names
  route53_zone_id           = module.route53_zone.zone_id
  tags                      = merge({ Name = "${var.project_name}-alb-cert" }, var.acm_tags)
}

module "iam_core" {
  source        = "./modules/iam_core"
  project_name  = var.project_name
  iam_role_name = var.iam_role_name

  create_bastion_role                = var.enable_bastion
  bastion_role_name                  = var.bastion_role_name != "" ? var.bastion_role_name : "${var.project_name}-bastion-role"
  create_bastion_instance_profile    = var.create_bastion_instance_profile
  bastion_instance_profile_name      = var.bastion_instance_profile_name != "" ? var.bastion_instance_profile_name : "${var.project_name}-bastion-profile"
  attach_cloudwatch_agent_to_bastion = var.attach_cloudwatch_agent_to_bastion
}

module "eks" {
  source                       = "./modules/eks"
  project_name                 = var.project_name
  k8s_version                  = var.k8s_version
  vpc_id                       = module.vpc.vpc_id
  subnet_ids                   = [module.vpc.pri_subnet_3a_id, module.vpc.pri_subnet_4b_id]
  eks_cluster_role_arn         = module.iam_core.eks_cluster_role_arn
  admin_role_arn               = module.iam_core.admin_role_arn
  admin_ec2_sg_id              = module.vpc.sg_id
  vpce_sg_id                   = module.vpc.vpce_sg_id
  create_vpce_nodes_https_rule = var.enable_ssm_endpoints || var.enable_ecr_cw_endpoints || var.enable_monitoring_endpoint || var.enable_sts_endpoint || var.enable_ec2_endpoint || var.enable_sqs_endpoint || var.enable_eks_endpoint
}


module "iam_irsa" {
  source            = "./modules/iam_irsa"
  project_name      = var.project_name
  oidc_provider_arn = module.eks.oidc_provider_arn
  route53_zone_id   = module.route53_zone.zone_id
}

module "node_group" {
  source                   = "./modules/node-group"
  eks_cluster_name         = module.eks.eks_cluster_name
  node_group_name          = var.node_group_name != "" ? var.node_group_name : "${module.eks.eks_cluster_name}-node-group"
  node_group_role_arn      = module.iam_core.node_group_role_arn
  pri_subnet_3a_id         = module.vpc.pri_subnet_3a_id
  pri_subnet_4b_id         = module.vpc.pri_subnet_4b_id
  node_group_instance_type = var.node_group_instance_type
  disk_size                = var.node_group_disk_size
  desired_size             = var.node_group_desired_size
  min_size                 = var.node_group_min_size
  max_size                 = var.node_group_max_size
  k8s_version              = var.k8s_version
  cluster_service_cidr     = module.eks.cluster_service_cidr
  depends_on               = [module.eks]
}

module "karpenter" {
  source       = "./modules/karpenter"
  cluster_name = module.eks.eks_cluster_name
  region       = var.region
  tags         = merge({ Name = "Karpenter-${var.project_name}" }, var.karpenter_tags)
  ssm_prefix   = var.ssm_prefix
  depends_on   = [module.eks]
}

module "bastion" {
  count                 = var.enable_bastion ? 1 : 0
  source                = "./modules/bastion"
  bastion_instance_type = var.bastion_instance_type
  bastion_instance_name = var.bastion_name
  key_name              = var.key_name
  subnet_id             = module.vpc.pub_subnet_1a_id
  security_group_id     = module.vpc.bastion_sg_id
  use_ssm               = var.bastion_use_ssm
  ami_ssm_parameter     = var.bastion_ami_ssm_parameter
  associate_public_ip   = var.bastion_associate_public_ip
  root_volume_size      = var.bastion_root_volume_size

  depends_on = [module.iam_core]
}

module "ec2" {
  source               = "./modules/ec2"
  instance_type        = var.instance_type
  instance_name        = var.instance_name
  key_name             = var.key_name
  subnet_id            = module.vpc.pri_subnet_3a_id
  security_group_id    = module.vpc.sg_id
  volume_size          = var.ec2_root_volume_size
  use_ssm              = var.use_ssm
  ami_ssm_parameter    = var.ami_ssm_parameter
  iam_instance_profile = module.iam_core.admin_instance_profile_name
  cluster_name         = module.eks.eks_cluster_name
  parent_zone          = var.zone_name
  cert_domain          = var.acm_domain_name
  ingress_group        = var.ingress_group
  ssl_redirect         = var.ssl_redirect
  ssm_prefix           = var.ssm_prefix

  depends_on = [
    module.eks,
    module.node_group,
    module.iam_core,
    module.karpenter,
    module.eks_managed_addons
  ]

}

module "eks_managed_addons" {
  source                = "./modules/eks-managed-addons"
  cluster_name          = module.eks.eks_cluster_name
  enable_network_policy = true
  ebs_csi_role_arn      = module.iam_irsa.ebs_csi_irsa_role_arn
  tags                  = { Name = "${var.project_name}-addons" }

  depends_on = [module.eks, module.iam_irsa]
}
