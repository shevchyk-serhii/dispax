variable "project_id" { type = string }
variable "region" { type = string }
variable "vpc_name" { type = string; default = "oktopus-vpc" }
variable "subnet_cidr" { type = string; default = "10.0.0.0/24" }
variable "psa_cidr" { type = string; default = "10.1.0.0/16" }
variable "connector_cidr" { type = string; default = "10.8.0.0/28" }

resource "google_compute_network" "vpc" {
  project                 = var.project_id
  name                    = var.vpc_name
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "subnet" {
  project       = var.project_id
  name          = "${var.vpc_name}-subnet"
  region        = var.region
  network       = google_compute_network.vpc.id
  ip_cidr_range = var.subnet_cidr
}

resource "google_compute_global_address" "psa_range" {
  project       = var.project_id
  name          = "${var.vpc_name}-psa-range"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  address       = "10.1.0.0"
  network       = google_compute_network.vpc.id
}

resource "google_service_networking_connection" "psa" {
  network                 = google_compute_network.vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.psa_range.name]
}

resource "google_vpc_access_connector" "connector" {
  project        = var.project_id
  name           = "oktopus-connector"
  region         = var.region
  network        = google_compute_network.vpc.name
  ip_cidr_range  = var.connector_cidr
  machine_type   = "e2-micro"
  min_instances  = 2
  max_instances  = 3
}

output "vpc_id" { value = google_compute_network.vpc.id }
output "vpc_name" { value = google_compute_network.vpc.name }
output "subnet_id" { value = google_compute_subnetwork.subnet.id }
output "connector_id" { value = google_vpc_access_connector.connector.id }
