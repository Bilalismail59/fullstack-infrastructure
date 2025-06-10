#!/bin/bash

# Script de nettoyage pour supprimer toute l'infrastructure GCP
set -e

PROJECT_ID="primordial-port-462408-q7"
ENVIRONMENT=${1:-preprod}

echo "🧹 Nettoyage de l'infrastructure GCP"
echo "Environment: $ENVIRONMENT"
echo "Project: $PROJECT_ID"
echo ""

read -p "  Êtes-vous sûr de vouloir supprimer toute l'infrastructure? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo " Opération annulée"
    exit 0
fi

echo " Authentification..."
gcloud auth activate-service-account --key-file=terraform/service-account-key.json
gcloud config set project $PROJECT_ID

echo " Suppression via Terraform..."
cd terraform

# Configuration du backend
cat > backend.tf << EOF
terraform {
  backend "gcs" {
    bucket = "${PROJECT_ID}-terraform-state"
    prefix = "${ENVIRONMENT}/terraform/state"
  }
}
EOF

terraform init
terraform destroy -auto-approve \
    -var="environment=$ENVIRONMENT" \
    -var="project_id=$PROJECT_ID" \
    -var="region=europe-west1" \
    -var="zone=europe-west1-b" \
    -var="db_password=SecurePassword123!"

cd ..

echo " Infrastructure supprimée avec succès"
