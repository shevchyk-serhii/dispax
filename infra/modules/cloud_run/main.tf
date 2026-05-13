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

variable "connector_id" {
  type = string # ID VPC Connector для зʼєднання з Cloud SQL
}

variable "db_private_ip" {
  type = string # Приватний IP адрес PostgreSQL (з модуля cloud_sql)
}

variable "db_name" {
  type    = string
  default = "oktopus" # Назва бази даних
}

variable "db_user" {
  type    = string
  default = "oktopus" # Юзер PostgreSQL
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
  name     = "oktopus"
  location = var.region

  template {
    service_account = var.cloudrun_sa_email # Від імені якого SA працює контейнер

    timeout = "3600s" # Максимальний час запиту 1 година (для WebSocket зʼєднань)

    scaling {
      min_instance_count = 1  # Завжди є мінімум 1 запущений екземпляр
                               # → немає cold start, WebSocket зʼєднання не рвуться
      max_instance_count = 10 # Максимум 10 екземплярів при навантаженні
    }

    vpc_access {
      connector = var.connector_id      # Через який VPC Connector йти до приватної мережі
      egress    = "PRIVATE_RANGES_ONLY" # Через VPC йде тільки трафік до приватних IP
                                         # Публічний трафік (Firebase, APIs) йде напряму
    }

    containers {
      image = var.image # Docker образ з Artifact Registry

      resources {
        limits = {
          cpu    = "1"     # 1 vCPU на екземпляр
          memory = "512Mi" # 512 MB RAM (JVM налаштований на -XX:MaxRAMPercentage=75%)
        }
      }

      # ── ENV ЗМІННІ (відкриті значення) ────────────────────────────────────

      env {
        name  = "DATABASE_URL"
        # jdbc:postgresql://10.x.x.x:5432/oktopus — підключення до Cloud SQL по приватному IP
        value = "jdbc:postgresql://${var.db_private_ip}:5432/${var.db_name}"
      }

      env {
        name  = "DATABASE_USER"
        value = var.db_user # "oktopus"
      }

      # PORT не передаємо — Cloud Run v2 виставляє його автоматично (зарезервована змінна)

      env {
        name  = "APP_ENV"
        value = "production" # Вмикає production режим Flyway (без seed даних)
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
  value = google_cloud_run_v2_service.app.uri # HTTPS URL сервісу (наприклад: https://oktopus-xxx-ew.a.run.app)
}
