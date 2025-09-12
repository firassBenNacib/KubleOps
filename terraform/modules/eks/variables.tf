variable "project_name" {
  description = "EKS cluster name base"
  type        = string
}

variable "k8s_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the cluster will live"
  type        = string
}

variable "subnet_ids" {
  description = "Subnets for data-plane/control-plane ENIs (private subnets)"
  type        = list(string)
}

variable "eks_cluster_role_arn" {
  description = "Existing IAM role ARN for the EKS control plane"
  type        = string
}

variable "admin_role_arn" {
  description = "Admin EC2 IAM role ARN to grant EKS access via access entries"
  type        = string
}

variable "admin_ec2_sg_id" {
  description = "Security Group ID of the admin EC2 instance allowed to reach the EKS API"
  type        = string
}

variable "vpce_sg_id" {
  description = "Security Group ID attached to VPC interface endpoints"
  type        = string
}

variable "create_vpce_nodes_https_rule" {
  description = "Whether to allow node SG to reach VPC endpoints on 443"
  type        = bool
}
