# ── ЗМІННІ ────────────────────────────────────────────────────────────────────

variable "project_id" {
  type = string
}

variable "github_org" {
  type = string # Юзернейм або організація на GitHub, наприклад "shevchyk"
}

variable "github_repo" {
  type = string # Назва репозиторію, наприклад "dispax"
}

# ── СЕРВІСНІ АКАУНТИ ──────────────────────────────────────────────────────────
# Сервісний акаунт — це "робочий юзер" для машин і сервісів (не для людей).
# Кожен ресурс діє від імені свого сервісного акаунта.

# Сервісний акаунт для Cloud Run (від його імені працює бекенд).
# Отримує доступ до секретів, може писати логи і метрики.
resource "google_service_account" "cloudrun_sa" {
  project      = var.project_id
  account_id   = "dispax-server-sa"
  display_name = "Dispax Cloud Run Service Account"
}

# Сервісний акаунт для GitHub Actions (від його імені деплоїться CI/CD).
# Отримує доступ до Artifact Registry і Cloud Run.
resource "google_service_account" "github_sa" {
  project      = var.project_id
  account_id   = "github-actions-sa"
  display_name = "GitHub Actions Deploy SA"
}

# ── ПРАВА ДЛЯ CLOUD RUN SA ────────────────────────────────────────────────────

# Дозволяє Cloud Run читати секрети з Secret Manager
resource "google_project_iam_member" "cloudrun_sa_secret_accessor" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.cloudrun_sa.email}"
}

# Дозволяє Cloud Run писати логи в Cloud Logging (щоб бачити ZIO логи в консолі GCP)
resource "google_project_iam_member" "cloudrun_sa_log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.cloudrun_sa.email}"
}

# Дозволяє Cloud Run відправляти метрики в Cloud Monitoring
resource "google_project_iam_member" "cloudrun_sa_metric_writer" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.cloudrun_sa.email}"
}

# ── ПРАВА ДЛЯ GITHUB ACTIONS SA ───────────────────────────────────────────────

# Дозволяє GitHub Actions пушити Docker образи в Artifact Registry
resource "google_project_iam_member" "github_sa_ar_writer" {
  project = var.project_id
  role    = "roles/artifactregistry.writer"
  member  = "serviceAccount:${google_service_account.github_sa.email}"
}

# Дозволяє GitHub Actions деплоїти нові ревізії в Cloud Run
resource "google_project_iam_member" "github_sa_run_admin" {
  project = var.project_id
  role    = "roles/run.admin"
  member  = "serviceAccount:${google_service_account.github_sa.email}"
}

# Дозволяє GitHub Actions SA використовувати Cloud Run SA при деплої.
# Потрібно бо при деплої Cloud Run вказуємо який SA використовувати для сервісу.
resource "google_service_account_iam_member" "github_sa_user" {
  service_account_id = google_service_account.cloudrun_sa.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.github_sa.email}"
}

# ── WORKLOAD IDENTITY FEDERATION ──────────────────────────────────────────────
# Дозволяє GitHub Actions авторизуватись в GCP БЕЗ збереження JSON-ключів.
# Механізм: GitHub видає короткоживучий OIDC токен → GCP обмінює на GCP токен.
# Це безпечніше ніж зберігати довгоживучий JSON ключ в GitHub Secrets.

# "Пул" — контейнер для зовнішніх identity провайдерів (GitHub, GitLab тощо)
resource "google_iam_workload_identity_pool" "github_pool" {
  project                   = var.project_id
  workload_identity_pool_id = "github-actions-pool"
  display_name              = "GitHub Actions Pool"
}

# Провайдер всередині пулу — конфігурує довіру до GitHub OIDC токенів.
# attribute_mapping: як поля з GitHub токену відображаються на GCP атрибути.
# attribute_condition: лише токени з нашого репозиторію (shevchyk/dispax) приймаються.
resource "google_iam_workload_identity_pool_provider" "github_provider" {
  project                            = var.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.github_pool.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-provider"
  display_name                       = "GitHub OIDC Provider"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com" # GitHub як OIDC провайдер
  }

  attribute_mapping = {
    "google.subject"       = "assertion.sub"        # Унікальний ID з GitHub токену
    "attribute.actor"      = "assertion.actor"      # Хто запустив workflow
    "attribute.repository" = "assertion.repository" # Назва репозиторію
  }

  # Приймаємо токени ТІЛЬКИ з нашого репо — захист від інших репозиторіїв
  attribute_condition = "assertion.repository == '${var.github_org}/${var.github_repo}'"
}

# Дозволяє GitHub Actions (через WIF) "ставати" github-actions-sa.
# principalSet = всі запити з нашого репозиторію через цей пул
resource "google_service_account_iam_member" "github_wif_binding" {
  service_account_id = google_service_account.github_sa.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github_pool.name}/attribute.repository/${var.github_org}/${var.github_repo}"
}

# ── ВИХОДИ ────────────────────────────────────────────────────────────────────

output "cloudrun_sa_email" {
  value = google_service_account.cloudrun_sa.email # Потрібен модулю cloud_run
}

output "github_sa_email" {
  value = google_service_account.github_sa.email # Вказується в GitHub Actions змінній WIF_SERVICE_ACCOUNT
}

output "workload_identity_provider" {
  value = google_iam_workload_identity_pool_provider.github_provider.name # Вказується в GitHub Actions змінній WIF_PROVIDER
}
