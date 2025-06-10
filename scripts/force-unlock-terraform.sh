#!/bin/bash

# Script pour forcer le déverrouillage de Terraform avec l'ID spécifique
set -e

PROJECT_ID=${GCP_PROJECT_ID:-"primordial-port-462408-q7"}
ENVIRONMENT=${1:-prod}
LOCK_ID="1749568679776904"  # ID du verrou bloqué

echo " FORCE UNLOCK de l'état Terraform"
echo "==================================="
echo "Environment: $ENVIRONMENT"
echo "Lock ID: $LOCK_ID"
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

# Configuration du backend
BUCKET_NAME="${PROJECT_ID}-terraform-state"
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

echo " Force unlock du verrou Terraform avec ID: $LOCK_ID"
terraform force-unlock -force $LOCK_ID

echo " Verrou supprimé avec succès!"

cd ..
