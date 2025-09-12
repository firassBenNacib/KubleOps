output "instance_id" {
  description = "The ID of the created EC2 instance"
  value       = module.ec2_instance.id
}

output "instance_public_ip" {
  description = "Public IP of the instance"
  value       = module.ec2_instance.public_ip
}

output "ec2_private_ip" {
  description = "Private IP of the instance"
  value       = module.ec2_instance.private_ip
}