output "vpc_id" {
  description = "ID of the VPC"
  value       = google_compute_network.main.id
}

output "frontend_instances" {
  description = "Frontend instance group"
  value       = google_compute_region_instance_group_manager.frontend.instance_group
}

output "backend_instances" {
  description = "Backend instance group"
  value       = google_compute_region_instance_group_manager.backend.instance_group
}

output "database_endpoint" {
  description = "Cloud SQL instance endpoint"
  value       = google_sql_database_instance.main.private_ip_address
  sensitive   = true
}

output "load_balancer_ip" {
  description = "Load balancer IP address"
  value       = google_compute_global_address.default.address
}

output "monitoring_instance_ip" {
  description = "Monitoring instance IP"
  value       = google_compute_instance.monitoring.network_interface[0].access_config[0].nat_ip
}

output "project_id" {
  description = "GCP Project ID"
  value       = var.project_id
}

output "region" {
  description = "GCP Region"
  value       = var.region
}
