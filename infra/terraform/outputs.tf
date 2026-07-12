output "public_ip" {
  description = "Public IP attached to the Safe-Byte instance."
  value       = ncloud_public_ip.app.public_ip
}

output "app_url" {
  description = "Safe-Byte backend API base URL."
  value       = "http://${ncloud_public_ip.app.public_ip}"
}

output "health_url" {
  description = "Health check endpoint."
  value       = "http://${ncloud_public_ip.app.public_ip}/health"
}

output "ssh_command" {
  description = "SSH command after bootstrap has created the deploy user."
  value       = "ssh ${var.deploy_user}@${ncloud_public_ip.app.public_ip}"
}

output "login_key_name" {
  description = "Ncloud login key name attached to the server."
  value       = local.login_key_name
}
