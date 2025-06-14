terraform {
  backend "gcs" {
    bucket = "fullstack-terraform-state-bucket"
    prefix = "preprod/terraform.tfstate"
  }
}
