#!/bin/bash

# Script simple pour débloquer le verrou Terraform
set -e

PROJECT_ID="primordial-port-462408-q7"
ENVIRONMENT="prod"
LOCK_ID="1749568679776904"

echo " DÉBLOCAGE SIMPLE DU VERROU TERRAFORM"
echo "======================================"

# Vérifier l'authentification
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q "@"; then
    echo " Non authentifié. Exécutez: gcloud auth login"
    exit 1
fi

# Configurer l'authentification par défaut si nécessaire
if ! gcloud auth application-default print-access-token >/dev/null 2>&1; then
    echo " Configuration de l'authentification par défaut..."
    gcloud auth application-default login --no-browser
fi

cd terraform

# Configuration simple
gcloud config set project $PROJECT_ID

# Configuration du backend
cat > backend.tf << EOF
terraform {
  backend "gcs" {
    bucket = "${PROJECT_ID}-terraform-state"
    prefix = "${ENVIRONMENT}/terraform/state"
  }
}
EOF

# Initialisation et déblocage
terraform init
terraform force-unlock -force $LOCK_ID

echo " Verrou débloqué!"

cd ..
