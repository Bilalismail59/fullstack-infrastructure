#!/bin/bash

# Script pour exécuter Terraform localement sans backend GCS
set -e

PROJECT_ID="primordial-port-462408-q7"
REGION="europe-west1"
ZONE="${REGION}-b"
ENVIRONMENT=${1:-prod}

echo " DÉPLOIEMENT TERRAFORM LOCAL"
echo "============================="
echo "Environment: $ENVIRONMENT"
echo "Project: $PROJECT_ID"
echo ""

cd terraform

# Configuration du backend local
cat > backend.tf << EOF
terraform {
  backend "local" {
    path = "terraform.tfstate"
  }
}
EOF

# Initialisation Terraform
echo " Initialisation Terraform..."
terraform init -reconfigure

# Plan Terraform
echo " Planification Terraform..."
terraform plan \
  -var="environment=$ENVIRONMENT" \
  -var="project_id=$PROJECT_ID" \
  -var="region=$REGION" \
  -var="zone=$ZONE" \
  -var="db_password=SecurePassword123!" \
  -out=tfplan-$ENVIRONMENT

echo " Plan Terraform créé avec succès!"
echo ""
echo "Pour appliquer le plan, exécutez:"
echo "  cd terraform && terraform apply tfplan-$ENVIRONMENT"

cd ..
