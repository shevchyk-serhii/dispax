variable "project_id" {
  type = string
}

variable "region" {
  type    = string
  default = "europe-west1"
}

variable "github_org" {
  type = string
}

variable "github_repo" {
  type = string
}

variable "db_password" {
  type      = string
  sensitive = true
}

variable "jwt_secret" {
  type      = string
  sensitive = true
}

variable "mapbox_token" {
  type      = string
  sensitive = true
}

variable "app_image" {
  type        = string
  description = "Full image URL for the initial deploy, e.g. europe-west1-docker.pkg.dev/taxi-app-98671/oktopus-docker/oktopus-server:latest"
  default     = "europe-west1-docker.pkg.dev/taxi-app-98671/oktopus-docker/oktopus-server:latest"
}
