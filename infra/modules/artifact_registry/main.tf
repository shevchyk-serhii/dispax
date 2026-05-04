variable "project_id" { type = string }
variable "region" { type = string }
variable "repository_id" { type = string; default = "oktopus-docker" }

resource "google_artifact_registry_repository" "docker" {
  project       = var.project_id
  location      = var.region
  repository_id = var.repository_id
  format        = "DOCKER"
}

output "repository_url" {
  value = "${var.region}-docker.pkg.dev/${var.project_id}/${var.repository_id}"
}
