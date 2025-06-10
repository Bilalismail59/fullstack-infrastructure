#!/bin/bash

# Script pour débloquer uniquement le verrou Terraform
set -e

PROJECT_ID=${GCP_PROJECT_ID:-"primordial-port-462408-q7"}
ENVIRONMENT=${1:-prod}
LOCK_ID="1749568679776904"

echo " DÉBLOCAGE DU VERROU TERRAFORM"
echo "==============================="
echo "Environment: $ENVIRONMENT"
echo "Lock ID: $LOCK_ID"
echo ""

# Vérifier l'authentification
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q "@"; then
    echo " Non authentifié. Exécutez: gcloud auth login"
    exit 1
fi

# Créer un fichier de clé de service temporaire
echo " Création d'un fichier de clé de service temporaire..."
gcloud iam service-accounts keys create terraform-key.json \
    --iam-account=ci-cd-service-account@${PROJECT_ID}.iam.gserviceaccount.com

cd terraform

# Configuration des credentials
export GOOGLE_APPLICATION_CREDENTIALS="../terraform-key.json"
gcloud config set project $PROJECT_ID

# Configuration du backend
BUCKET_NAME="${PROJECT_ID}-terraform-state"
cat > backend.tf << EOF
terraform {
  backend "gcs" {
    bucket      = "$BUCKET_NAME"
    prefix      = "$ENVIRONMENT/terraform/state"
    credentials = "../terraform-key.json"
  }
}
EOF

echo " Initialisation Terraform..."
terraform init

echo " Force unlock du verrou..."
terraform force-unlock -force $LOCK_ID

echo " Verrou débloqué avec succès!"

# Nettoyage
cd ..
rm -f terraform-key.json
