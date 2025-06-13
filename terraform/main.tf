terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 5.0"
    }
  }

  backend "gcs" {
    bucket      = "tf-state-bucket"  # À remplacer par votre variable
    prefix      = "terraform-state"
    credentials = "service-account-key.json"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

# Enable required APIs
resource "google_project_service" "compute" {
  service            = "compute.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "container" {
  service            = "container.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "sql" {
  service            = "sqladmin.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "monitoring" {
  service            = "monitoring.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "servicenetworking" {
  service            = "servicenetworking.googleapis.com"
  disable_on_destroy = false
}

# VPC Network
resource "google_compute_network" "main" {
  name                    = "${var.project_name}-vpc"
  auto_create_subnetworks = false
  depends_on              = [google_project_service.compute]
  
  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      routing_mode,
      mtu
    ]
  }
}

# Subnet for Web Tier
resource "google_compute_subnetwork" "web" {
  name          = "${var.project_name}-web-subnet"
  ip_cidr_range = "10.0.1.0/24"
  region        = var.region
  network       = google_compute_network.main.id

  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = "10.1.0.0/16"
  }

  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = "10.2.0.0/16"
  }
  
  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      secondary_ip_range,
      creation_timestamp,
      gateway_address
    ]
  }
}

# Subnet for Database Tier
resource "google_compute_subnetwork" "db" {
  name          = "${var.project_name}-db-subnet"
  ip_cidr_range = "10.0.2.0/24"
  region        = var.region
  network       = google_compute_network.main.id
  
  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      creation_timestamp,
      gateway_address
    ]
  }
}

# Firewall Rules
resource "google_compute_firewall" "allow_http" {
  name    = "${var.project_name}-allow-http"
  network = google_compute_network.main.name

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["web-server"]
  
  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      direction,
      priority
    ]
  }
}

resource "google_compute_firewall" "allow_ssh" {
  name    = "${var.project_name}-allow-ssh"
  network = google_compute_network.main.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = [var.admin_cidr]
  target_tags   = ["web-server"]
  
  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      direction,
      priority
    ]
  }
}

resource "google_compute_firewall" "allow_internal" {
  name    = "${var.project_name}-allow-internal"
  network = google_compute_network.main.name

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }

  source_ranges = ["10.0.0.0/8"]
  
  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      direction,
      priority
    ]
  }
}

resource "google_compute_firewall" "allow_monitoring" {
  name    = "${var.project_name}-allow-monitoring"
  network = google_compute_network.main.name

  allow {
    protocol = "tcp"
    ports    = ["9090", "3000", "9100", "9093"]
  }

  source_ranges = ["10.0.0.0/8"]
  target_tags   = ["monitoring"]
  
  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      direction,
      priority
    ]
  }
}

# [Le reste de votre configuration existante reste inchangé...]

# Service Account for Compute Instances
resource "google_service_account" "compute" {
  account_id   = "${var.project_name}-compute-sa"
  display_name = "Compute Service Account"
  
  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      description
    ]
  }
}

resource "google_project_iam_member" "compute_monitoring" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.compute.email}"
  
  lifecycle {
    prevent_destroy = true
  }
}

resource "google_project_iam_member" "compute_logging" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.compute.email}"
  
  lifecycle {
    prevent_destroy = true
  }
}