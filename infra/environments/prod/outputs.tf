output "service_url" {
  description = "Cloud Run service URL"
  value       = module.cloud_run.service_url
}

output "db_private_ip" {
  description = "Cloud SQL private IP address"
  value       = module.cloud_sql.private_ip_address
}

output "registry_url" {
  description = "Artifact Registry Docker repository URL"
  value       = module.artifact_registry.repository_url
}

output "workload_identity_provider" {
  description = "Workload Identity provider for GitHub Actions (set as WIF_PROVIDER variable in GitHub)"
  value       = module.iam.workload_identity_provider
}

output "github_sa_email" {
  description = "GitHub Actions service account email (set as WIF_SERVICE_ACCOUNT variable in GitHub)"
  value       = module.iam.github_sa_email
}
