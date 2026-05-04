variable "project_id" { type = string }
variable "region" { type = string }
variable "vpc_id" { type = string }
variable "db_name" { type = string; default = "oktopus" }
variable "db_user" { type = string; default = "oktopus" }
variable "db_password" { type = string; sensitive = true }

resource "google_sql_database_instance" "postgres" {
  project          = var.project_id
  name             = "oktopus-postgres"
  region           = var.region
  database_version = "POSTGRES_16"

  deletion_protection = true

  settings {
    tier              = "db-f1-micro"
    availability_type = "ZONAL"
    disk_type         = "PD_SSD"
    disk_size         = 10
    disk_autoresize   = true

    disk_autoresize_limit = 50

    backup_configuration {
      enabled    = true
      start_time = "02:00"

      backup_retention_settings {
        retained_backups = 7
      }
    }

    ip_configuration {
      ipv4_enabled    = false
      private_network = var.vpc_id
    }
  }
}

resource "google_sql_database" "db" {
  project  = var.project_id
  name     = var.db_name
  instance = google_sql_database_instance.postgres.name
}

resource "google_sql_user" "user" {
  project  = var.project_id
  name     = var.db_user
  instance = google_sql_database_instance.postgres.name
  password = var.db_password
}

output "private_ip_address" {
  value = google_sql_database_instance.postgres.private_ip_address
}

output "connection_name" {
  value = google_sql_database_instance.postgres.connection_name
}
