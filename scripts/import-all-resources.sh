#!/bin/bash

# Script pour importer toutes les ressources existantes
set -e

PROJECT_ID=${GCP_PROJECT_ID:-"primordial-port-462408-q7"}
REGION=${GCP_REGION:-"europe-west1"}
ENVIRONMENT=${1:-prod}

echo " IMPORTATION FORCÉE DE TOUTES LES RESSOURCES"
echo "=============================================="
echo "Environment: $ENVIRONMENT"
echo "Project: $PROJECT_ID"
echo ""

cd terraform

# Configuration des credentials
export GOOGLE_APPLICATION_CREDENTIALS="$(pwd)/service-account-key.json"
gcloud config set project $PROJECT_ID

# Configuration du backend local
cat > backend.tf << EOF
terraform {
  backend "local" {
    path = "terraform-${ENVIRONMENT}.tfstate"
  }
}
EOF

echo " Initialisation Terraform..."
terraform init -reconfigure

# Fonction d'importation simplifiée
import_if_exists() {
    local TF_RESOURCE=$1
    local GCP_RESOURCE_ID=$2
    local RESOURCE_NAME=$3
    
    echo " Importation de $RESOURCE_NAME..."
    
    # Vérifier si déjà dans l'état
    if terraform state show $TF_RESOURCE >/dev/null 2>&1; then
        echo " $RESOURCE_NAME déjà importé"
        return 0
    fi
    
    # Tenter l'importation
    if terraform import $TF_RESOURCE "$GCP_RESOURCE_ID" 2>/dev/null; then
        echo " $RESOURCE_NAME importé avec succès"
    else
        echo " Échec importation $RESOURCE_NAME (sera créé)"
    fi
}

echo " Importation des ressources principales..."

# 1. VPC Network
import_if_exists \
    "google_compute_network.main" \
    "projects/$PROJECT_ID/global/networks/fullstack-app-vpc" \
    "VPC Network"

# 2. Subnets
import_if_exists \
    "google_compute_subnetwork.web" \
    "projects/$PROJECT_ID/regions/$REGION/subnetworks/fullstack-app-web-subnet" \
    "Web Subnet"

import_if_exists \
    "google_compute_subnetwork.db" \
    "projects/$PROJECT_ID/regions/$REGION/subnetworks/fullstack-app-db-subnet" \
    "DB Subnet"

# 3. Firewall Rules
import_if_exists \
    "google_compute_firewall.allow_http" \
    "projects/$PROJECT_ID/global/firewalls/fullstack-app-allow-http" \
    "HTTP Firewall"

import_if_exists \
    "google_compute_firewall.allow_ssh" \
    "projects/$PROJECT_ID/global/firewalls/fullstack-app-allow-ssh" \
    "SSH Firewall"

import_if_exists \
    "google_compute_firewall.allow_internal" \
    "projects/$PROJECT_ID/global/firewalls/fullstack-app-allow-internal" \
    "Internal Firewall"

import_if_exists \
    "google_compute_firewall.allow_monitoring" \
    "projects/$PROJECT_ID/global/firewalls/fullstack-app-allow-monitoring" \
    "Monitoring Firewall"

# 4. Health Checks
import_if_exists \
    "google_compute_health_check.frontend" \
    "projects/$PROJECT_ID/global/healthChecks/fullstack-app-frontend-hc" \
    "Frontend Health Check"

import_if_exists \
    "google_compute_health_check.backend" \
    "projects/$PROJECT_ID/global/healthChecks/fullstack-app-backend-hc" \
    "Backend Health Check"

# 5. Global Address
import_if_exists \
    "google_compute_global_address.default" \
    "projects/$PROJECT_ID/global/addresses/fullstack-app-lb-ip" \
    "Load Balancer IP"

# 6. Service Account
import_if_exists \
    "google_service_account.compute" \
    "projects/$PROJECT_ID/serviceAccounts/fullstack-app-compute-sa@$PROJECT_ID.iam.gserviceaccount.com" \
    "Compute Service Account"

# 7. Private IP Address
import_if_exists \
    "google_compute_global_address.private_ip_address" \
    "projects/$PROJECT_ID/global/addresses/fullstack-app-private-ip" \
    "Private IP Address"

# 8. Cloud SQL Instance
import_if_exists \
    "google_sql_database_instance.main" \
    "$PROJECT_ID:fullstack-app-$ENVIRONMENT-db" \
    "Cloud SQL Instance"

# 9. SQL Database
import_if_exists \
    "google_sql_database.wordpress" \
    "$PROJECT_ID/fullstack-app-$ENVIRONMENT-db/wordpress" \
    "WordPress Database"

# 10. SQL User
import_if_exists \
    "google_sql_user.wordpress" \
    "$PROJECT_ID/fullstack-app-$ENVIRONMENT-db/wordpress" \
    "WordPress DB User"

echo ""
echo " Importation terminée!"
echo "État Terraform actuel:"
terraform state list

cd ..
