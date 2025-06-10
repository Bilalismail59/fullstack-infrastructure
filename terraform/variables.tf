variable "project_id" {
  description = "GCP Project ID"
  type        = string
  default     = "primordial-port-462408-q7"
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "europe-west1"
}

variable "zone" {
  description = "GCP zone"
  type        = string
  default     = "europe-west1-b"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "fullstack-app"
}

variable "environment" {
  description = "Environment (preprod/prod)"
  type        = string
  validation {
    condition     = contains(["preprod", "prod"], var.environment)
    error_message = "Environment must be either 'preprod' or 'prod'."
  }
}

variable "machine_type" {
  description = "GCE machine type"
  type        = string
  default     = "e2-micro"
}

variable "image_family" {
  description = "OS image family"
  type        = string
  default     = "ubuntu-2004-lts"
}

variable "admin_cidr" {
  description = "CIDR block for admin access"
  type        = string
  default     = "0.0.0.0/0"
}

variable "db_tier" {
  description = "Cloud SQL tier"
  type        = string
  default     = "db-f1-micro"
}

variable "db_password" {
  description = "Database password"
  type        = string
  sensitive   = true
}

variable "domain_name" {
  description = "Domain name for SSL certificate"
  type        = string
  default     = ""
}
