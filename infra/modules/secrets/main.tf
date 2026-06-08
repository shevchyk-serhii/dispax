# ── ЗМІННІ ────────────────────────────────────────────────────────────────────

variable "project_id" {
  type = string
}

variable "db_password" {
  type      = string
  sensitive = true # Не відображати в логах Terraform
}

variable "jwt_secret" {
  type      = string
  sensitive = true
}

variable "mapbox_token" {
  type      = string
  sensitive = true
}

# ── РЕСУРСИ ───────────────────────────────────────────────────────────────────

# Зводимо всі секрети в одну map для зручного циклічного створення
locals {
  secrets = {
    "dispax-db-password"  = var.db_password  # Пароль PostgreSQL юзера
    "dispax-jwt-secret"   = var.jwt_secret   # Секрет для підпису JWT токенів
    "dispax-mapbox-token" = var.mapbox_token # Токен Mapbox для геокодингу
  }
}

# Створює "контейнер" для кожного секрету в Google Secret Manager.
# Secret — це лише оболонка з метаданими (назва, реплікація).
# Саме значення зберігається у SecretVersion (нижче).
resource "google_secret_manager_secret" "secrets" {
  for_each  = local.secrets
  project   = var.project_id
  secret_id = each.key # Наприклад: "dispax-db-password"

  replication {
    auto {} # GCP сам обирає регіони для реплікації (найпростіший варіант)
  }
}

# Зберігає саме значення секрету як нову версію.
# Secret Manager підтримує версіонування — можна відкотити до попередньої версії.
resource "google_secret_manager_secret_version" "versions" {
  for_each    = local.secrets
  secret      = google_secret_manager_secret.secrets[each.key].id
  secret_data = each.value # Саме значення (пароль, токен тощо)
}

# ── ВИХОДИ ────────────────────────────────────────────────────────────────────
# Передаємо ID секретів в модуль cloud_run для монтування як env змінних

output "db_password_secret_id" {
  value = google_secret_manager_secret.secrets["dispax-db-password"].id
}

output "jwt_secret_secret_id" {
  value = google_secret_manager_secret.secrets["dispax-jwt-secret"].id
}

output "mapbox_token_secret_id" {
  value = google_secret_manager_secret.secrets["dispax-mapbox-token"].id
}
