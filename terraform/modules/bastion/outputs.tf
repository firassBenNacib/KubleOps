output "bastion_instance_id" {
  description = "The ID of the bastion EC2 instance"
  value       = module.bastion_instance.id
}

output "bastion_public_ip" {
  description = "The public IP address of the bastion host"
  value       = module.bastion_instance.public_ip
}

output "bastion_private_ip" {
  description = "The private IP address of the bastion host"
  value       = module.bastion_instance.private_ip
}

output "bastion_instance_name" {
  description = "The Name tag of the bastion host"
  value       = var.bastion_instance_name
}
