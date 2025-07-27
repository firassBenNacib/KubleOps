output "alb_controller_role_arn" {
  value = module.iam.alb_controller_role_arn
}
output "bastion_public_ip" {
  value       = module.bastion.bastion_public_ip
  description = "Public IP of the bastion host"
}
