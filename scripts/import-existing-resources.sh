#!/bin/bash

# Script dédié pour importer les ressources existantes dans l'état Terraform
set -e

PROJECT_ID=${GCP_PROJECT_ID:-"primordial-port-462408-q7"}
REGION=${GCP_REGION:-"europe-west1"}
ENVIRONMENT=${1:-prod}

echo " Importation des ressources existantes dans Terraform"
echo "====================================================="
echo "Environment: $ENVIRONMENT"
echo "Project: $PROJECT_ID"
echo "Region: $REGION"
echo ""

cd terraform

# Configuration des credentials
if [ -n "$GITHUB_ACTIONS" ]; then
    echo " Configuration GitHub Actions..."
    export GOOGLE_APPLICATION_CREDENTIALS="$(pwd)/service-account-key.json"
    gcloud auth activate-service-account --key-file=service-account-key.json
    gcloud config set project $PROJECT_ID
else
    echo " Configuration locale..."
    if [ ! -f "service-account-key.json" ]; then
        echo " Fichier service-account-key.json manquant"
        exit 1
    fi
    export GOOGLE_APPLICATION_CREDENTIALS="$(pwd)/service-account-key.json"
    gcloud auth activate-service-account --key-file=service-account-key.json
    gcloud config set project $PROJECT_ID
fi

# Créer le bucket Terraform state
BUCKET_NAME="${PROJECT_ID}-terraform-state"
echo " Configuration du bucket Terraform state..."

if gsutil ls -b gs://$BUCKET_NAME/ >/dev/null 2>&1; then
    echo " Bucket state existe déjà"
else
    echo " Création du bucket state..."
    gsutil mb -p $PROJECT_ID -c STANDARD -l $REGION gs://$BUCKET_NAME/
    gsutil versioning set on gs://$BUCKET_NAME/
fi

# Configuration du backend
cat > backend.tf << EOF
terraform {
  backend "gcs" {
    bucket      = "$BUCKET_NAME"
    prefix      = "$ENVIRONMENT/terraform/state"
    credentials = "service-account-key.json"
  }
}
EOF

echo " Initialisation Terraform..."
terraform init

# Fonction pour importer une ressource si elle existe et n'est pas dans l'état
import_resource() {
    local TF_RESOURCE=$1
    local GCP_RESOURCE_ID=$2
    local RESOURCE_NAME=$3
    local CHECK_COMMAND=$4
    
    echo "Vérification de $RESOURCE_NAME..."
    
    # Vérifier si la ressource existe dans l'état Terraform
    if terraform state show $TF_RESOURCE >/dev/null 2>&1; then
        echo " $RESOURCE_NAME déjà dans l'état Terraform"
        return 0
    fi
    
    # Vérifier si la ressource existe dans GCP
    if eval $CHECK_COMMAND >/dev/null 2>&1; then
        echo " Importation de $RESOURCE_NAME..."
        if terraform import $TF_RESOURCE "$GCP_RESOURCE_ID" >/dev/null 2>&1; then
            echo " $RESOURCE_NAME importé avec succès"
        else
            echo " Échec de l'importation de $RESOURCE_NAME"
        fi
    else
        echo " $RESOURCE_NAME n'existe pas dans GCP, sera créé"
    fi
}

echo ""
echo " Importation des ressources principales..."

# 1. VPC Network
import_resource \
    "google_compute_network.main" \
    "projects/$PROJECT_ID/global/networks/fullstack-app-vpc" \
    "VPC Network" \
    "gcloud compute networks describe fullstack-app-vpc --project=$PROJECT_ID --quiet"

# 2. Subnets
import_resource \
    "google_compute_subnetwork.web" \
    "projects/$PROJECT_ID/regions/$REGION/subnetworks/fullstack-app-web-subnet" \
    "Web Subnet" \
    "gcloud compute networks subnets describe fullstack-app-web-subnet --region=$REGION --project=$PROJECT_ID --quiet"

import_resource \
    "google_compute_subnetwork.db" \
    "projects/$PROJECT_ID/regions/$REGION/subnetworks/fullstack-app-db-subnet" \
    "DB Subnet" \
    "gcloud compute networks subnets describe fullstack-app-db-subnet --region=$REGION --project=$PROJECT_ID --quiet"

# 3. Firewall Rules
import_resource \
    "google_compute_firewall.allow_http" \
    "projects/$PROJECT_ID/global/firewalls/fullstack-app-allow-http" \
    "HTTP Firewall Rule" \
    "gcloud compute firewall-rules describe fullstack-app-allow-http --project=$PROJECT_ID --quiet"

import_resource \
    "google_compute_firewall.allow_ssh" \
    "projects/$PROJECT_ID/global/firewalls/fullstack-app-allow-ssh" \
    "SSH Firewall Rule" \
    "gcloud compute firewall-rules describe fullstack-app-allow-ssh --project=$PROJECT_ID --quiet"

import_resource \
    "google_compute_firewall.allow_internal" \
    "projects/$PROJECT_ID/global/firewalls/fullstack-app-allow-internal" \
    "Internal Firewall Rule" \
    "gcloud compute firewall-rules describe fullstack-app-allow-internal --project=$PROJECT_ID --quiet"

import_resource \
    "google_compute_firewall.allow_monitoring" \
    "projects/$PROJECT_ID/global/firewalls/fullstack-app-allow-monitoring" \
    "Monitoring Firewall Rule" \
    "gcloud compute firewall-rules describe fullstack-app-allow-monitoring --project=$PROJECT_ID --quiet"

# 4. Health Checks
import_resource \
    "google_compute_health_check.frontend" \
    "projects/$PROJECT_ID/global/healthChecks/fullstack-app-frontend-hc" \
    "Frontend Health Check" \
    "gcloud compute health-checks describe fullstack-app-frontend-hc --project=$PROJECT_ID --quiet"

import_resource \
    "google_compute_health_check.backend" \
    "projects/$PROJECT_ID/global/healthChecks/fullstack-app-backend-hc" \
    "Backend Health Check" \
    "gcloud compute health-checks describe fullstack-app-backend-hc --project=$PROJECT_ID --quiet"

# 5. Global Address
import_resource \
    "google_compute_global_address.default" \
    "projects/$PROJECT_ID/global/addresses/fullstack-app-lb-ip" \
    "Load Balancer IP" \
    "gcloud compute addresses describe fullstack-app-lb-ip --global --project=$PROJECT_ID --quiet"

# 6. Private IP Address
import_resource \
    "google_compute_global_address.private_ip_address" \
    "projects/$PROJECT_ID/global/addresses/fullstack-app-private-ip" \
    "Private IP Address" \
    "gcloud compute addresses describe fullstack-app-private-ip --global --project=$PROJECT_ID --quiet"

# 7. Service Account
import_resource \
    "google_service_account.compute" \
    "projects/$PROJECT_ID/serviceAccounts/fullstack-app-compute-sa@$PROJECT_ID.iam.gserviceaccount.com" \
    "Compute Service Account" \
    "gcloud iam service-accounts describe fullstack-app-compute-sa@$PROJECT_ID.iam.gserviceaccount.com --project=$PROJECT_ID --quiet"

# 8. Cloud SQL Instance
import_resource \
    "google_sql_database_instance.main" \
    "$PROJECT_ID:fullstack-app-$ENVIRONMENT-db" \
    "Cloud SQL Instance" \
    "gcloud sql instances describe fullstack-app-$ENVIRONMENT-db --project=$PROJECT_ID --quiet"

# 9. SQL Database
import_resource \
    "google_sql_database.wordpress" \
    "$PROJECT_ID/fullstack-app-$ENVIRONMENT-db/wordpress" \
    "WordPress Database" \
    "gcloud sql databases describe wordpress --instance=fullstack-app-$ENVIRONMENT-db --project=$PROJECT_ID --quiet"

# 10. SQL User
import_resource \
    "google_sql_user.wordpress" \
    "$PROJECT_ID/fullstack-app-$ENVIRONMENT-db/wordpress" \
    "WordPress DB User" \
    "gcloud sql users describe wordpress --instance=fullstack-app-$ENVIRONMENT-db --project=$PROJECT_ID --quiet"

echo ""
echo " Importation terminée!"
echo "État Terraform actuel:"
terraform state list

cd ..
