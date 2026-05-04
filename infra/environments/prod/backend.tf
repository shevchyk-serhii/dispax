terraform {
  backend "gcs" {
    bucket = "taxi-app-98671-terraform-state"
    prefix = "oktopus/prod"
  }
}
