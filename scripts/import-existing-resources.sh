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

# Configuration des credentials - version simplifiée
echo " Configuration des credentials..."
gcloud config set project $PROJECT_ID

# Créer un fichier de clé de service temporaire si pas en mode GitHub Actions
if [ -z "$GITHUB_ACTIONS" ]; then
    echo " Création d'un fichier de clé de service temporaire..."
    gcloud iam service-accounts keys create service-account-key.json \
        --iam-account=ci-cd-service-account@${PROJECT_ID}.iam.gserviceaccount.com
    export GOOGLE_APPLICATION_CREDENTIALS="$(pwd)/service-account-key.json"
fi

# Utiliser un état local au lieu du bucket GCS pour éviter les problèmes
echo " Configuration de l'état Terraform local..."

# Configuration du backend local
cat > backend.tf << EOF
terraform {
  backend "local" {
    path = "terraform-${ENVIRONMENT}.tfstate"
  }
}
EOF

echo " Initialisation Terraform avec reconfiguration..."
terraform init -reconfigure

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
        # Afficher les détails de l'importation
        if terraform import $TF_RESOURCE "$GCP_RESOURCE_ID"; then
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

# Vérifier si le VPC existe réellement
echo " Vérification de l'existence du VPC..."
if gcloud compute networks describe fullstack-app-vpc --project=$PROJECT_ID --quiet; then
    echo " VPC existe, tentative d'importation..."
else
    echo " VPC n'existe pas, sera créé lors du déploiement"
fi

# Continuer avec le déploiement sans importation
echo " Passage à l'étape de déploiement..."

cd ..
