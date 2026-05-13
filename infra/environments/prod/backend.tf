terraform {
  backend "gcs" {
    bucket = "project-6efcac64-terraform-state"
    prefix = "oktopus/prod"
  }
}
