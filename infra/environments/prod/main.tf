terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.6"
}

provider "google" {
  project = var.project_id
  region  = var.region
}

module "apis" {
  source     = "../../modules/apis"
  project_id = var.project_id
}

module "iam" {
  source      = "../../modules/iam"
  project_id  = var.project_id
  github_org  = var.github_org
  github_repo = var.github_repo

  depends_on = [module.apis]
}

module "networking" {
  source     = "../../modules/networking"
  project_id = var.project_id
  region     = var.region

  depends_on = [module.apis]
}

module "artifact_registry" {
  source     = "../../modules/artifact_registry"
  project_id = var.project_id
  region     = var.region

  depends_on = [module.apis]
}

module "cloud_sql" {
  source      = "../../modules/cloud_sql"
  project_id  = var.project_id
  region      = var.region
  vpc_id      = module.networking.vpc_id
  db_password = var.db_password

  depends_on = [module.networking]
}

module "secrets" {
  source       = "../../modules/secrets"
  project_id   = var.project_id
  db_password  = var.db_password
  jwt_secret   = var.jwt_secret
  mapbox_token = var.mapbox_token

  depends_on = [module.apis]
}

module "cloud_run" {
  source                 = "../../modules/cloud_run"
  project_id             = var.project_id
  region                 = var.region
  image                  = var.app_image
  connector_id           = module.networking.connector_id
  db_private_ip          = module.cloud_sql.private_ip_address
  cloudrun_sa_email      = module.iam.cloudrun_sa_email
  db_password_secret_id  = module.secrets.db_password_secret_id
  jwt_secret_secret_id   = module.secrets.jwt_secret_secret_id
  mapbox_token_secret_id = module.secrets.mapbox_token_secret_id

  depends_on = [module.cloud_sql, module.secrets, module.iam, module.artifact_registry]
}
