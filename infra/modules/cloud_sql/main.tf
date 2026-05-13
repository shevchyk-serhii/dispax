# ── ЗМІННІ ────────────────────────────────────────────────────────────────────

variable "project_id" {
  type = string
}

variable "region" {
  type = string
}

variable "vpc_id" {
  type = string # ID мережі VPC — для підключення Cloud SQL до приватної мережі
}

variable "db_name" {
  type    = string
  default = "oktopus" # Назва бази даних всередині PostgreSQL
}

variable "db_user" {
  type    = string
  default = "oktopus" # Імʼя юзера PostgreSQL
}

variable "db_password" {
  type      = string
  sensitive = true # Terraform не буде показувати це значення в логах і плані
}

# ── РЕСУРСИ ───────────────────────────────────────────────────────────────────

# Головний ресурс — екземпляр Cloud SQL (managed PostgreSQL).
# GCP сам керує: ОС, патчі безпеки, бекапи, failover.
resource "google_sql_database_instance" "postgres" {
  project          = var.project_id
  name             = "oktopus-postgres"
  region           = var.region
  database_version = "POSTGRES_16" # PostgreSQL версія 16 (відповідає docker-compose.yml)

  deletion_protection = true # Захист від випадкового `terraform destroy` — треба спочатку вимкнути вручну

  settings {
    tier              = "db-f1-micro" # Найдешевший тир: 1 shared vCPU, 614MB RAM (~$10/міс)
    availability_type = "ZONAL"       # Одна зона (не HA) — економія 50% для MVP
    disk_type         = "PD_SSD"      # SSD диск (швидше ніж HDD)
    disk_size         = 10            # 10 GB початковий розмір
    disk_autoresize   = true          # Автоматично збільшується при потребі

    disk_autoresize_limit = 50 # Максимум 50 GB (захист від несподіваних витрат)

    backup_configuration {
      enabled    = true    # Автоматичні бекапи ввімкнені
      start_time = "02:00" # Час бекапу: 02:00 UTC (мінімальне навантаження)

      backup_retention_settings {
        retained_backups = 7 # Зберігати бекапи 7 днів
      }
    }

    ip_configuration {
      ipv4_enabled    = false    # Публічний IP вимкнений — БД недоступна з інтернету
      private_network = var.vpc_id # Підключення тільки через приватний VPC
    }
  }
}

# База даних всередині PostgreSQL екземпляра
resource "google_sql_database" "db" {
  project  = var.project_id
  name     = var.db_name   # "oktopus"
  instance = google_sql_database_instance.postgres.name
}

# Юзер PostgreSQL з яким підключається бекенд
resource "google_sql_user" "user" {
  project  = var.project_id
  name     = var.db_user     # "oktopus"
  instance = google_sql_database_instance.postgres.name
  password = var.db_password # Пароль з Secret Manager / tfvars
}

# ── ВИХОДИ ────────────────────────────────────────────────────────────────────

output "private_ip_address" {
  value = google_sql_database_instance.postgres.private_ip_address # Передається в Cloud Run як DATABASE_URL
}

output "connection_name" {
  value = google_sql_database_instance.postgres.connection_name # project:region:instance (для Auth Proxy якщо знадобиться)
}
