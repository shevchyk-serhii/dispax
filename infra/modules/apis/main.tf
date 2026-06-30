# ID проекту GCP — передається з кореневого модуля
variable "project_id" {
  type = string
}

# Список GCP API які треба ввімкнути.
# GCP за замовчуванням вимикає всі сервіси — треба явно дозволити кожен.
locals {
  apis = [
    "run.googleapis.com",                  # Cloud Run — запуск контейнерів без сервера
    "sqladmin.googleapis.com",             # Cloud SQL — managed PostgreSQL
    "servicenetworking.googleapis.com",    # Private Services Access — приватний IP для Cloud SQL у VPC
    "vpcaccess.googleapis.com",            # VPC Access Connector — міст між Cloud Run і VPC
    "secretmanager.googleapis.com",        # Secret Manager — безпечне зберігання паролів і токенів
    "artifactregistry.googleapis.com",     # Artifact Registry — приватний Docker репозиторій
    "cloudresourcemanager.googleapis.com", # Resource Manager — потрібен Terraform для керування IAM
    "iam.googleapis.com",                  # IAM — сервісні акаунти і права доступу
    "compute.googleapis.com",              # Compute Engine — VPC, підмережі, мережеві ресурси
    "iamcredentials.googleapis.com",       # IAM Credentials — Workload Identity для GitHub Actions
    "cloudscheduler.googleapis.com",       # Cloud Scheduler — cron-перемикання CPU/min-instances Cloud Run
  ]
}

# Вмикає кожен API в проекті.
# for_each = toset(local.apis) створює окремий ресурс для кожного рядка зі списку.
# disable_on_destroy = false: при `terraform destroy` API НЕ вимикаються
# (щоб не зламати інші ресурси які могли існувати до Terraform)
resource "google_project_service" "apis" {
  for_each = toset(local.apis)

  project            = var.project_id
  service            = each.value # Наприклад: "run.googleapis.com"
  disable_on_destroy = false
}
