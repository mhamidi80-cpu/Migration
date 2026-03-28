# --- Networking Outputs ---
output "vpc_id" {
  description = "The ID of the Migration Target VPC"
  value       = module.networking.vpc_id
}

output "transit_gateway_id" {
  description = "The ID of the TGW bridging to On-Prem"
  value       = module.networking.tgw_id
}

# --- Compute & Web Tier Outputs ---
output "web_server_public_ip" {
  description = "The public IP of the Nginx/React Web Server"
  value       = module.compute.web_public_ip
}

# --- Database Outputs ---
output "rds_hostname" {
  description = "The connection endpoint for the Multi-AZ RDS"
  value       = module.compute.db_endpoint
}

output "database_admin_user" {
  description = "The administrative username for the RDS"
  value       = "m.hamidi"
}

