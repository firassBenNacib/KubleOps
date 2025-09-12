variable "eks_cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "node_group_name" {
  description = "Explicit name for the EKS managed node group"
  type        = string
}

variable "node_group_role_arn" {
  description = "ARN of the IAM role to attach to the node group"
  type        = string
}

variable "pri_subnet_3a_id" {
  description = "ID of private subnet 3a"
  type        = string
}

variable "pri_subnet_4b_id" {
  description = "ID of private subnet 4b"
  type        = string
}

variable "desired_size" {
  description = "Desired number of worker nodes"
  type        = number
}

variable "min_size" {
  description = "Minimum number of worker nodes"
  type        = number
}

variable "max_size" {
  description = "Maximum number of worker nodes"
  type        = number
}

variable "disk_size" {
  description = "Disk size in GiB for each worker node"
  type        = number
}

variable "node_group_instance_type" {
  description = "EC2 instance type for worker nodes"
  type        = string
}

variable "k8s_version" {
  description = "Kubernetes version for the node group"
  type        = string
}

variable "cluster_service_cidr" {
  description = "The CIDR block where Kubernetes service IPs are assigned from"
  type        = string
}
