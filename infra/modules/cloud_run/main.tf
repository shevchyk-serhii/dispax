variable "project_id" { type = string }
variable "region" { type = string }
variable "image" { type = string }
variable "connector_id" { type = string }
variable "db_private_ip" { type = string }
variable "db_name" { type = string; default = "oktopus" }
variable "db_user" { type = string; default = "oktopus" }
variable "cloudrun_sa_email" { type = string }
variable "db_password_secret_id" { type = string }
variable "jwt_secret_secret_id" { type = string }
variable "mapbox_token_secret_id" { type = string }

resource "google_cloud_run_v2_service" "app" {
  project  = var.project_id
  name     = "oktopus"
  location = var.region

  template {
    service_account = var.cloudrun_sa_email

    timeout = "3600s"

    scaling {
      min_instance_count = 1
      max_instance_count = 10
    }

    vpc_access {
      connector = var.connector_id
      egress    = "PRIVATE_RANGES_ONLY"
    }

    containers {
      image = var.image

      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
      }

      env {
        name  = "DATABASE_URL"
        value = "jdbc:postgresql://${var.db_private_ip}:5432/${var.db_name}"
      }

      env {
        name  = "DATABASE_USER"
        value = var.db_user
      }

      env {
        name  = "PORT"
        value = "8080"
      }

      env {
        name  = "APP_ENV"
        value = "production"
      }

      env {
        name = "DATABASE_PASSWORD"
        value_source {
          secret_key_ref {
            secret  = var.db_password_secret_id
            version = "latest"
          }
        }
      }

      env {
        name = "JWT_SECRET"
        value_source {
          secret_key_ref {
            secret  = var.jwt_secret_secret_id
            version = "latest"
          }
        }
      }

      env {
        name = "MAPBOX_ACCESS_TOKEN"
        value_source {
          secret_key_ref {
            secret  = var.mapbox_token_secret_id
            version = "latest"
          }
        }
      }

      ports {
        container_port = 8080
      }

      startup_probe {
        http_get {
          path = "/health"
          port = 8080
        }
        initial_delay_seconds = 30
        period_seconds        = 10
        failure_threshold     = 6
      }

      liveness_probe {
        http_get {
          path = "/health"
          port = 8080
        }
        period_seconds    = 30
        failure_threshold = 3
      }
    }
  }
}

resource "google_cloud_run_v2_service_iam_member" "public" {
  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.app.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

output "service_url" {
  value = google_cloud_run_v2_service.app.uri
}
