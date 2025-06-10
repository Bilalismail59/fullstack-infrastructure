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
  service = "compute.googleapis.com"
}

resource "google_project_service" "container" {
  service = "container.googleapis.com"
}

resource "google_project_service" "sql" {
  service = "sqladmin.googleapis.com"
}

resource "google_project_service" "monitoring" {
  service = "monitoring.googleapis.com"
}

# VPC Network
resource "google_compute_network" "main" {
  name                    = "${var.project_name}-vpc"
  auto_create_subnetworks = false
  depends_on              = [google_project_service.compute]
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
}

# Subnet for Database Tier
resource "google_compute_subnetwork" "db" {
  name          = "${var.project_name}-db-subnet"
  ip_cidr_range = "10.0.2.0/24"
  region        = var.region
  network       = google_compute_network.main.id
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
}

# Instance Template for Frontend
resource "google_compute_instance_template" "frontend" {
  name_prefix  = "${var.project_name}-frontend-"
  machine_type = var.machine_type

  disk {
    source_image = var.image_family
    auto_delete  = true
    boot         = true
    disk_size_gb = 20
  }

  network_interface {
    subnetwork = google_compute_subnetwork.web.id
    access_config {
      // Ephemeral public IP
    }
  }

  metadata = {
    startup-script = templatefile("${path.module}/startup-scripts/frontend.sh", {
      environment = var.environment
      project_id  = var.project_id
    })
  }

  tags = ["web-server", "frontend"]

  service_account {
    email  = google_service_account.compute.email
    scopes = ["cloud-platform"]
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Instance Template for Backend
resource "google_compute_instance_template" "backend" {
  name_prefix  = "${var.project_name}-backend-"
  machine_type = var.machine_type

  disk {
    source_image = var.image_family
    auto_delete  = true
    boot         = true
    disk_size_gb = 20
  }

  network_interface {
    subnetwork = google_compute_subnetwork.web.id
  }

  metadata = {
    startup-script = templatefile("${path.module}/startup-scripts/backend.sh", {
      environment = var.environment
      project_id  = var.project_id
      db_host     = google_sql_database_instance.main.private_ip_address
      db_password = var.db_password
    })
  }

  tags = ["web-server", "backend"]

  service_account {
    email  = google_service_account.compute.email
    scopes = ["cloud-platform"]
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Managed Instance Group for Frontend
resource "google_compute_region_instance_group_manager" "frontend" {
  name   = "${var.project_name}-frontend-mig"
  region = var.region

  base_instance_name = "${var.project_name}-frontend"
  target_size        = var.environment == "prod" ? 2 : 1

  version {
    instance_template = google_compute_instance_template.frontend.id
  }

  named_port {
    name = "http"
    port = 80
  }

  auto_healing_policies {
    health_check      = google_compute_health_check.frontend.id
    initial_delay_sec = 300
  }
}

# Managed Instance Group for Backend
resource "google_compute_region_instance_group_manager" "backend" {
  name   = "${var.project_name}-backend-mig"
  region = var.region

  base_instance_name = "${var.project_name}-backend"
  target_size        = var.environment == "prod" ? 2 : 1

  version {
    instance_template = google_compute_instance_template.backend.id
  }

  named_port {
    name = "http"
    port = 80
  }

  auto_healing_policies {
    health_check      = google_compute_health_check.backend.id
    initial_delay_sec = 300
  }
}

# Health Checks
resource "google_compute_health_check" "frontend" {
  name = "${var.project_name}-frontend-hc"

  http_health_check {
    port         = 80
    request_path = "/"
  }

  check_interval_sec  = 30
  timeout_sec         = 5
  healthy_threshold   = 2
  unhealthy_threshold = 3
}

resource "google_compute_health_check" "backend" {
  name = "${var.project_name}-backend-hc"

  http_health_check {
    port         = 80
    request_path = "/wp-admin/install.php"
  }

  check_interval_sec  = 30
  timeout_sec         = 5
  healthy_threshold   = 2
  unhealthy_threshold = 3
}

# Load Balancer
resource "google_compute_global_address" "default" {
  name = "${var.project_name}-lb-ip"
}

resource "google_compute_backend_service" "frontend" {
  name        = "${var.project_name}-frontend-backend"
  protocol    = "HTTP"
  port_name   = "http"
  timeout_sec = 30

  backend {
    group = google_compute_region_instance_group_manager.frontend.instance_group
  }

  health_checks = [google_compute_health_check.frontend.id]
}

resource "google_compute_backend_service" "backend" {
  name        = "${var.project_name}-backend-backend"
  protocol    = "HTTP"
  port_name   = "http"
  timeout_sec = 30

  backend {
    group = google_compute_region_instance_group_manager.backend.instance_group
  }

  health_checks = [google_compute_health_check.backend.id]
}

resource "google_compute_url_map" "default" {
  name            = "${var.project_name}-url-map"
  default_service = google_compute_backend_service.frontend.id

  host_rule {
    hosts        = ["api.${var.domain_name}"]
    path_matcher = "api"
  }

  path_matcher {
    name            = "api"
    default_service = google_compute_backend_service.backend.id
  }
}

resource "google_compute_target_http_proxy" "default" {
  name    = "${var.project_name}-http-proxy"
  url_map = google_compute_url_map.default.id
}

resource "google_compute_global_forwarding_rule" "default" {
  name       = "${var.project_name}-forwarding-rule"
  target     = google_compute_target_http_proxy.default.id
  port_range = "80"
  ip_address = google_compute_global_address.default.address
}

# SSL Certificate (if domain is provided)
resource "google_compute_managed_ssl_certificate" "default" {
  count = var.domain_name != "" ? 1 : 0
  name  = "${var.project_name}-ssl-cert"

  managed {
    domains = [var.domain_name, "api.${var.domain_name}"]
  }
}

resource "google_compute_target_https_proxy" "default" {
  count           = var.domain_name != "" ? 1 : 0
  name            = "${var.project_name}-https-proxy"
  url_map         = google_compute_url_map.default.id
  ssl_certificates = [google_compute_managed_ssl_certificate.default[0].id]
}

resource "google_compute_global_forwarding_rule" "https" {
  count      = var.domain_name != "" ? 1 : 0
  name       = "${var.project_name}-https-forwarding-rule"
  target     = google_compute_target_https_proxy.default[0].id
  port_range = "443"
  ip_address = google_compute_global_address.default.address
}

# Cloud SQL Instance
resource "google_sql_database_instance" "main" {
  name             = "${var.project_name}-${var.environment}-db"
  database_version = "MYSQL_8_0"
  region           = var.region

  settings {
    tier = var.db_tier

    backup_configuration {
      enabled                        = true
      start_time                     = "03:00"
      point_in_time_recovery_enabled = var.environment == "prod"
      backup_retention_settings {
        retained_backups = var.environment == "prod" ? 7 : 3
      }
    }

    ip_configuration {
      ipv4_enabled    = false
      private_network = google_compute_network.main.id
      require_ssl     = true
    }

    database_flags {
      name  = "slow_query_log"
      value = "on"
    }

    maintenance_window {
      day          = 7
      hour         = 4
      update_track = "stable"
    }
  }

  deletion_protection = var.environment == "prod"
  depends_on          = [google_service_networking_connection.private_vpc_connection]
}

# Private VPC Connection for Cloud SQL
resource "google_compute_global_address" "private_ip_address" {
  name          = "${var.project_name}-private-ip"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.main.id
}

resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = google_compute_network.main.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_address.name]
}

# Database and User
resource "google_sql_database" "wordpress" {
  name     = "wordpress"
  instance = google_sql_database_instance.main.name
}

resource "google_sql_user" "wordpress" {
  name     = "wordpress"
  instance = google_sql_database_instance.main.name
  password = var.db_password
}

# Service Account for Compute Instances
resource "google_service_account" "compute" {
  account_id   = "${var.project_name}-compute-sa"
  display_name = "Compute Service Account"
}

resource "google_project_iam_member" "compute_monitoring" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.compute.email}"
}

resource "google_project_iam_member" "compute_logging" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.compute.email}"
}

# Monitoring Instance
resource "google_compute_instance" "monitoring" {
  name         = "${var.project_name}-monitoring"
  machine_type = "e2-medium"
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = var.image_family
      size  = 30
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.web.id
    access_config {
      // Ephemeral public IP
    }
  }

  metadata = {
    startup-script = file("${path.module}/startup-scripts/monitoring.sh")
  }

  tags = ["monitoring", "web-server"]

  service_account {
    email  = google_service_account.compute.email
    scopes = ["cloud-platform"]
  }
}
