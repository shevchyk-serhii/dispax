variable "project_id" { type = string }
variable "db_password" { type = string; sensitive = true }
variable "jwt_secret" { type = string; sensitive = true }
variable "mapbox_token" { type = string; sensitive = true }

locals {
  secrets = {
    "oktopus-db-password"  = var.db_password
    "oktopus-jwt-secret"   = var.jwt_secret
    "oktopus-mapbox-token" = var.mapbox_token
  }
}

resource "google_secret_manager_secret" "secrets" {
  for_each  = local.secrets
  project   = var.project_id
  secret_id = each.key

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "versions" {
  for_each    = local.secrets
  secret      = google_secret_manager_secret.secrets[each.key].id
  secret_data = each.value
}

output "db_password_secret_id" {
  value = google_secret_manager_secret.secrets["oktopus-db-password"].id
}

output "jwt_secret_secret_id" {
  value = google_secret_manager_secret.secrets["oktopus-jwt-secret"].id
}

output "mapbox_token_secret_id" {
  value = google_secret_manager_secret.secrets["oktopus-mapbox-token"].id
}
