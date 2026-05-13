# Вказуємо які провайдери потрібні Terraform і їх версії
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google" # Офіційний провайдер для GCP від HashiCorp
      version = "~> 5.0"           # Версія 5.x (будь-яка patch/minor, але не 6.x)
    }
  }
  required_version = ">= 1.6" # Мінімальна версія самого Terraform
}

# Налаштовуємо GCP провайдер — до якого проекту і регіону підключатись
provider "google" {
  project = var.project_id # ID проекту в GCP (з terraform.tfvars)
  region  = var.region     # Регіон за замовчуванням (europe-west1 = Франкфурт)
}

# ── МОДУЛЬ: APIs ──────────────────────────────────────────────────────────────
# Вмикає потрібні GCP API в проекті. За замовчуванням більшість API вимкнені.
# Без цього кроку жоден інший ресурс не може бути створений.
module "apis" {
  source     = "../../modules/apis"
  project_id = var.project_id
}

# ── МОДУЛЬ: IAM ───────────────────────────────────────────────────────────────
# Створює сервісні акаунти і права доступу:
#   - oktopus-server-sa: від імені якого працює Cloud Run (читає секрети, пише логи)
#   - github-actions-sa: від імені якого GitHub Actions пушить образи і деплоїть
#   - Workload Identity Federation: GitHub Actions авторизується без JSON-ключів
module "iam" {
  source      = "../../modules/iam"
  project_id  = var.project_id
  github_org  = var.github_org  # Організація/юзер на GitHub (з tfvars)
  github_repo = var.github_repo # Назва репозиторію на GitHub (з tfvars)

  depends_on = [module.apis] # APIs мають бути ввімкнені перед створенням IAM ресурсів
}

# ── МОДУЛЬ: NETWORKING ────────────────────────────────────────────────────────
# Створює приватну мережу (VPC) в GCP:
#   - VPC: ізольована мережа для всіх ресурсів проекту
#   - Subnet: підмережа в регіоні europe-west1
#   - PSA (Private Services Access): дозволяє Cloud SQL мати приватний IP у нашому VPC
#   - VPC Connector: міст між Cloud Run (serverless) і приватним VPC
#     Без нього Cloud Run не може звʼязатись з Cloud SQL по приватному IP
module "networking" {
  source     = "../../modules/networking"
  project_id = var.project_id
  region     = var.region

  depends_on = [module.apis]
}

# ── МОДУЛЬ: ARTIFACT REGISTRY ─────────────────────────────────────────────────
# Docker-репозиторій в GCP для зберігання образів контейнерів.
# GitHub Actions пушить сюди образ після кожного деплою.
# Cloud Run звідси тягне образ для запуску.
# Аналог: Docker Hub, але приватний і в тому ж GCP проекті.
module "artifact_registry" {
  source     = "../../modules/artifact_registry"
  project_id = var.project_id
  region     = var.region

  depends_on = [module.apis]
}

# ── МОДУЛЬ: CLOUD SQL ─────────────────────────────────────────────────────────
# Managed PostgreSQL 16 база даних в GCP.
# "Managed" = GCP сам робить бекапи, патчить ОС, моніторить диск.
# Підключається ТІЛЬКИ по приватному IP через VPC (публічний IP вимкнений).
# Cloud Run звʼязується з нею через VPC Connector (з модуля networking).
module "cloud_sql" {
  source      = "../../modules/cloud_sql"
  project_id  = var.project_id
  region      = var.region
  vpc_id      = module.networking.vpc_id # В якій мережі розмістити БД
  db_password = var.db_password          # Пароль для юзера БД (sensitive)

  depends_on = [module.networking] # Мережа має існувати перед створенням БД
}

# ── МОДУЛЬ: SECRETS ───────────────────────────────────────────────────────────
# Google Secret Manager — безпечне сховище для чутливих даних.
# Зберігає: пароль БД, JWT секрет, Mapbox токен.
# Cloud Run читає ці значення при старті контейнера як env змінні.
# Перевага: секрети не видно в логах і консолі GCP, доступ контролюється IAM.
module "secrets" {
  source       = "../../modules/secrets"
  project_id   = var.project_id
  db_password  = var.db_password  # Той самий пароль що і для Cloud SQL
  jwt_secret   = var.jwt_secret   # Секрет для підпису JWT токенів авторизації
  mapbox_token = var.mapbox_token # Токен для Mapbox API (геокодинг в Flutter)

  depends_on = [module.apis]
}

# ── МОДУЛЬ: CLOUD RUN ─────────────────────────────────────────────────────────
# Запускає Docker контейнер з бекендом (Scala/ZIO).
# Cloud Run — serverless: GCP сам керує VM, балансуванням, SSL, автоскейлінгом.
# min_instance_count=1 → завжди є 1 запущений екземпляр (WebSocket не рветься).
# Контейнер підʼєднується до БД через VPC Connector по приватному IP.
# Секрети з Secret Manager монтуються як env змінні всередині контейнера.
module "cloud_run" {
  source                 = "../../modules/cloud_run"
  project_id             = var.project_id
  region                 = var.region
  image                  = var.app_image                        # Docker образ для запуску
  connector_id           = module.networking.connector_id       # VPC Connector для зʼєднання з БД
  db_private_ip          = module.cloud_sql.private_ip_address  # Приватний IP PostgreSQL
  cloudrun_sa_email      = module.iam.cloudrun_sa_email         # Сервісний акаунт для Cloud Run
  db_password_secret_id  = module.secrets.db_password_secret_id # Посилання на секрет в Secret Manager
  jwt_secret_secret_id   = module.secrets.jwt_secret_secret_id
  mapbox_token_secret_id = module.secrets.mapbox_token_secret_id

  depends_on = [module.cloud_sql, module.secrets, module.iam, module.artifact_registry]
}
