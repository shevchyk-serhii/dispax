# ── ЗМІННІ ────────────────────────────────────────────────────────────────────

variable "project_id" {
  type = string
}

variable "region" {
  type = string
}

variable "image" {
  type = string # Повний шлях до Docker образу в Artifact Registry
}

variable "vpc_name" {
  type = string # VPC network name for Direct VPC egress (reach Cloud SQL private IP)
}

variable "subnet_name" {
  type = string # Regional subnet name for Direct VPC egress (must match the run region)
}

variable "public_base_url" {
  type    = string
  default = "https://dispax-o2trzxjbva-ew.a.run.app" # Base for guest-tracking links
}

variable "db_private_ip" {
  type = string # Приватний IP адрес PostgreSQL (з модуля cloud_sql)
}

variable "db_name" {
  type    = string
  default = "dispax" # Назва бази даних
}

variable "db_user" {
  type    = string
  default = "dispax" # Юзер PostgreSQL
}

variable "cloudrun_sa_email" {
  type = string # Сервісний акаунт від імені якого працює контейнер
}

variable "db_password_secret_id" {
  type = string # ID секрету в Secret Manager з паролем БД
}

variable "jwt_secret_secret_id" {
  type = string # ID секрету в Secret Manager з JWT ключем
}

variable "mapbox_token_secret_id" {
  type = string # ID секрету в Secret Manager з Mapbox токеном
}

# ── РЕСУРС: CLOUD RUN SERVICE ─────────────────────────────────────────────────
# Основний сервіс — запускає Docker контейнер з Scala бекендом.
# Cloud Run автоматично: SSL, домен, балансування, автоскейлінг.
resource "google_cloud_run_v2_service" "app" {
  project  = var.project_id
  name     = "dispax"
  location = var.region

  template {
    service_account = var.cloudrun_sa_email # Від імені якого SA працює контейнер

    timeout = "3600s" # Максимальний час запиту 1 година (для WebSocket зʼєднань)

    scaling {
      # NOTE: min_instance_count and resources.cpu_idle are RUNTIME-OWNED by the
      # scheduler module (cron flips them on/off) — see lifecycle.ignore_changes
      # below. The values here are only the baseline used when the service is first
      # created / fully recreated; the scheduler overrides them on a schedule.
      min_instance_count = 0  # baseline = scale-to-zero (off-hours / weekends)
      max_instance_count = 10 # Максимум 10 екземплярів при навантаженні
    }

    # Direct VPC egress — connects Cloud Run straight to the VPC subnet to reach
    # Cloud SQL over its private IP, WITHOUT a Serverless VPC Access connector.
    # This removes the connector's always-on e2-micro machines (~€10/mo Compute Engine).
    vpc_access {
      network_interfaces {
        network    = var.vpc_name    # Private VPC network
        subnetwork = var.subnet_name # Regional subnet (must match Cloud Run region)
      }
      egress = "PRIVATE_RANGES_ONLY" # Only private-IP traffic goes through the VPC;
                                      # public traffic (Firebase, APIs) goes direct
    }

    containers {
      image = var.image # Docker образ з Artifact Registry

      resources {
        cpu_idle          = true # baseline = CPU throttled (runtime-owned by scheduler,
                                 # see lifecycle.ignore_changes — cron flips it on/off)
        startup_cpu_boost = true # Faster JVM cold start (matches live config)
        limits = {
          cpu = "1" # 1 vCPU на екземпляр
          # 1 GiB RAM. 512Mi was too tight for JVM cold start (OOM at ~532Mi during
          # startup, revision never reached Ready → 500s on a true cold start from
          # scale-to-zero). Memory is billed only during active request-seconds /
          # the always-on window, so this costs ~a couple EUR/mo at most.
          memory = "1Gi"
        }
      }

      # ── ENV ЗМІННІ (відкриті значення) ────────────────────────────────────

      env {
        name  = "DATABASE_URL"
        # jdbc:postgresql://10.x.x.x:5432/dispax — підключення до Cloud SQL по приватному IP
        value = "jdbc:postgresql://${var.db_private_ip}:5432/${var.db_name}"
      }

      env {
        name  = "DATABASE_USER"
        value = var.db_user # "dispax"
      }

      # PORT не передаємо — Cloud Run v2 виставляє його автоматично (зарезервована змінна)

      env {
        name  = "APP_ENV"
        value = "production" # Вмикає production режим Flyway (без seed даних)
      }

      env {
        name  = "PUBLIC_BASE_URL"
        # Base for absolute guest-tracking links (<base>/track/<token>).
        # Managed in TF so a targeted apply does not drop it (was set out-of-band).
        value = var.public_base_url
      }

      # ── ENV ЗМІННІ (з Secret Manager) ─────────────────────────────────────
      # Ці значення GCP підставляє з Secret Manager при старті контейнера.
      # Вони ніде не логуються і не видні в консолі GCP.

      env {
        name = "DATABASE_PASSWORD" # Пароль PostgreSQL юзера
        value_source {
          secret_key_ref {
            secret  = var.db_password_secret_id # Який секрет читати
            version = "latest"                  # Остання версія секрету
          }
        }
      }

      env {
        name = "JWT_SECRET" # Секрет для підпису JWT токенів авторизації
        value_source {
          secret_key_ref {
            secret  = var.jwt_secret_secret_id
            version = "latest"
          }
        }
      }

      env {
        name = "MAPBOX_ACCESS_TOKEN" # Токен для Mapbox геокодингу
        value_source {
          secret_key_ref {
            secret  = var.mapbox_token_secret_id
            version = "latest"
          }
        }
      }

      ports {
        container_port = 8080 # Порт контейнера який Cloud Run відкриває назовні
      }

      # Перевірка при старті: чекає поки /health повертає 200.
      # Якщо за 60 сек (30s delay + 6 спроб × 5s) не відповість — рестарт.
      startup_probe {
        http_get {
          path = "/health"
          port = 8080
        }
        initial_delay_seconds = 30 # Чекати 30 сек перед першою перевіркою (JVM старт)
        period_seconds        = 10 # Перевіряти кожні 10 сек
        failure_threshold     = 6  # 6 невдалих спроб → контейнер вважається мертвим
      }

      # Перевірка під час роботи: якщо /health не відповідає 3 рази — рестарт.
      liveness_probe {
        http_get {
          path = "/health"
          port = 8080
        }
        period_seconds    = 30 # Перевіряти кожні 30 сек
        failure_threshold = 3  # 3 невдалі спроби → рестарт контейнера
      }
    }
  }

  # The scheduler module (cron) owns these two fields at runtime — flipping them
  # on/off on a schedule. Without ignore_changes, the next `terraform apply` would
  # revert whatever the scheduler last set, and the two systems would drift-war.
  lifecycle {
    ignore_changes = [
      template[0].scaling[0].min_instance_count,
      template[0].containers[0].resources[0].cpu_idle,
    ]
  }
}

# Робить Cloud Run сервіс публічно доступним (без авторизації).
# "allUsers" = будь-який користувач в інтернеті може зробити HTTP запит.
# Авторизація відбувається на рівні самого бекенду (JWT токени).
resource "google_cloud_run_v2_service_iam_member" "public" {
  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.app.name
  role     = "roles/run.invoker"
  member   = "allUsers" # Публічний доступ
}

# ── ВИХОДИ ────────────────────────────────────────────────────────────────────

output "service_url" {
  value = google_cloud_run_v2_service.app.uri # HTTPS URL сервісу (наприклад: https://dispax-xxx-ew.a.run.app)
}
