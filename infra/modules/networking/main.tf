# ── ЗМІННІ ────────────────────────────────────────────────────────────────────

variable "project_id" {
  type = string
}

variable "region" {
  type = string # Регіон для підмережі і VPC Connector (europe-west1)
}

variable "vpc_name" {
  type    = string
  default = "dispax-vpc" # Назва приватної мережі
}

variable "subnet_cidr" {
  type    = string
  default = "10.0.0.0/24" # Діапазон IP для підмережі (254 адреси)
}

variable "psa_cidr" {
  type    = string
  default = "10.1.0.0/16" # Діапазон IP зарезервований для сервісів GCP (Cloud SQL)
}

variable "connector_cidr" {
  type    = string
  default = "10.8.0.0/28" # Маленький діапазон для VPC Connector (16 адрес, мінімум)
}

# ── РЕСУРСИ ───────────────────────────────────────────────────────────────────

# Головна приватна мережа проекту.
# auto_create_subnetworks = false: керуємо підмережами вручну, не автоматично
resource "google_compute_network" "vpc" {
  project                 = var.project_id
  name                    = var.vpc_name
  auto_create_subnetworks = false
}

# Підмережа всередині VPC для europe-west1 (Франкфурт).
# Всі наші ресурси (Cloud SQL, VPC Connector) будуть в цій підмережі.
resource "google_compute_subnetwork" "subnet" {
  project       = var.project_id
  name          = "${var.vpc_name}-subnet"
  region        = var.region
  network       = google_compute_network.vpc.id
  ip_cidr_range = var.subnet_cidr # 10.0.0.0/24
}

# Резервує діапазон IP для приватного підʼєднання сервісів GCP (Cloud SQL).
# Cloud SQL отримає IP з цього діапазону, і буде доступна в нашому VPC.
resource "google_compute_global_address" "psa_range" {
  project       = var.project_id
  name          = "${var.vpc_name}-psa-range"
  purpose       = "VPC_PEERING"  # Тип: для пірингу з сервісами GCP
  address_type  = "INTERNAL"     # Внутрішня адреса (не публічна)
  prefix_length = 16             # Маска /16 = 65534 адреси для сервісів GCP
  address       = "10.1.0.0"
  network       = google_compute_network.vpc.id
}

# Встановлює пірінг між нашим VPC і мережею сервісів GCP.
# Після цього Cloud SQL отримає приватний IP і буде доступна з нашого VPC.
resource "google_service_networking_connection" "psa" {
  network                 = google_compute_network.vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.psa_range.name]
}

# VPC Access Connector — міст між Cloud Run і приватним VPC.
# Cloud Run за замовчуванням ізольований від приватних мереж.
# Через цей конектор Cloud Run може звертатись до Cloud SQL по приватному IP.
# machine_type = "e2-micro": найдешевший тип ноди для конектора
# min/max_instances: кількість нод конектора (2-3 для MVP)
resource "google_vpc_access_connector" "connector" {
  project       = var.project_id
  name          = "dispax-connector"
  region        = var.region
  network       = google_compute_network.vpc.name
  ip_cidr_range = var.connector_cidr # 10.8.0.0/28 — окремий діапазон для конектора
  machine_type  = "e2-micro"
  min_instances = 2
  max_instances = 3
}

# ── ВИХОДИ (outputs) ──────────────────────────────────────────────────────────
# Передаємо значення в інші модулі які їх потребують

output "vpc_id" {
  value = google_compute_network.vpc.id # Потрібен модулю cloud_sql для PSA
}

output "vpc_name" {
  value = google_compute_network.vpc.name
}

output "subnet_id" {
  value = google_compute_subnetwork.subnet.id
}

output "connector_id" {
  value = google_vpc_access_connector.connector.id # Потрібен модулю cloud_run
}
