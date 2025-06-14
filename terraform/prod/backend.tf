terraform {
  backend "gcs" {
    bucket  = "fullstack-terraform-state-prod"   # Ton bucket GCS de prod !
    prefix  = "terraform/prod/state"             # Un préfixe unique pour prod
  }
}
