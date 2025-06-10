#!/bin/bash

# Script pour déployer l'infrastructure complète avec support GitHub Actions
set -e

# Récupérer les variables d'environnement ou utiliser les valeurs par défaut
PROJECT_ID=${GCP_PROJECT_ID:-"primordial-port-462408-q7"}
REGION=${GCP_REGION:-"europe-west1"}
ZONE="${REGION}-b"

echo " Déploiement de l'infrastructure complète"
echo "==========================================="

# Détection de l'environnement
if [ -n "$GITHUB_ACTIONS" ]; then
    echo " Mode GitHub Actions détecté"
    ENVIRONMENT=${1:-preprod}
else
    echo " Mode déploiement local"
    ENVIRONMENT=${1:-preprod}
    
    # Vérifier les prérequis locaux
    if ! command -v gcloud >/dev/null 2>&1; then
        echo " gcloud CLI manquant. Exécutez: ./scripts/install-tools.sh"
        exit 1
    fi
    
    if ! command -v terraform >/dev/null 2>&1; then
        echo " Terraform manquant. Exécutez: ./scripts/install-tools.sh"
        exit 1
    fi
fi

echo "Environment: $ENVIRONMENT"
echo "Project: $PROJECT_ID"
echo "Region: $REGION"
echo ""

# Confirmation pour la production
if [ "$ENVIRONMENT" = "prod" ] && [ -z "$GITHUB_ACTIONS" ]; then
    read -p "  Déploiement en PRODUCTION. Continuer? (yes/no): " confirm
    if [ "$confirm" != "yes" ]; then
        echo " Déploiement annulé"
        exit 0
    fi
fi

cd terraform

# Configuration des credentials selon l'environnement
if [ -n "$GITHUB_ACTIONS" ]; then
    echo " Configuration GitHub Actions..."
    export GOOGLE_APPLICATION_CREDENTIALS="$(pwd)/service-account-key.json"
    
    # Authentifier gcloud avec le service account
    gcloud auth activate-service-account --key-file=service-account-key.json
    gcloud config set project $PROJECT_ID
    
    # Vérifier l'authentification
    echo " Vérification de l'authentification..."
    gcloud auth list
    gcloud config list project
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

# Créer le bucket Terraform state avec gestion d'erreur
BUCKET_NAME="${PROJECT_ID}-terraform-state"
echo " Configuration du bucket Terraform state..."

# Vérifier si le bucket existe
if gsutil ls -b gs://$BUCKET_NAME/ >/dev/null 2>&1; then
    echo " Bucket state existe déjà"
else
    echo " Création du bucket state..."
    gsutil mb -p $PROJECT_ID -c STANDARD -l $REGION gs://$BUCKET_NAME/
fi

# Activer le versioning seulement si nécessaire
if gsutil versioning get gs://$BUCKET_NAME/ | grep -q "Enabled"; then
    echo " Versioning déjà activé"
else
    echo " Activation du versioning..."
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

# Vérifier s'il y a un verrou bloqué et le supprimer si nécessaire
echo " Vérification des verrous Terraform..."
if ! terraform plan -detailed-exitcode -var="environment=$ENVIRONMENT" -var="project_id=$PROJECT_ID" -var="region=$REGION" -var="zone=$ZONE" -var="db_password=${DB_PASSWORD:-SecurePassword123!}" >/dev/null 2>&1; then
    if terraform plan -var="environment=$ENVIRONMENT" -var="project_id=$PROJECT_ID" -var="region=$REGION" -var="zone=$ZONE" -var="db_password=${DB_PASSWORD:-SecurePassword123!}" 2>&1 | grep -q "Error acquiring the state lock"; then
        echo " Verrou détecté, tentative de déverrouillage automatique..."
        
        # Extraire l'ID du verrou depuis l'erreur
        LOCK_ID=$(terraform plan -var="environment=$ENVIRONMENT" -var="project_id=$PROJECT_ID" -var="region=$REGION" -var="zone=$ZONE" -var="db_password=${DB_PASSWORD:-SecurePassword123!}" 2>&1 | grep "ID:" | awk '{print $2}' | head -1)
        
        if [ -n "$LOCK_ID" ]; then
            echo " Suppression du verrou $LOCK_ID..."
            terraform force-unlock -force $LOCK_ID || echo " Impossible de supprimer le verrou automatiquement"
        fi
    fi
fi

# Vérifier si des ressources existent déjà et les importer avec gestion d'erreur
echo " Vérification des ressources existantes..."

# Fonction pour importer une ressource si elle existe (avec gestion du verrou)
import_if_exists() {
    local RESOURCE_TYPE=$1
    local RESOURCE_NAME=$2
    local RESOURCE_ID=$3
    local TF_RESOURCE=$4
    
    if gcloud $RESOURCE_TYPE describe $RESOURCE_NAME --project=$PROJECT_ID $5 >/dev/null 2>&1; then
        echo " Importation de $RESOURCE_NAME dans Terraform..."
        terraform import $TF_RESOURCE $RESOURCE_ID 2>/dev/null || echo " $RESOURCE_NAME déjà importé ou erreur d'import"
    fi
}

# Importer les ressources existantes (sans arrêter en cas d'erreur)
import_if_exists "compute networks" "fullstack-app-vpc" "projects/$PROJECT_ID/global/networks/fullstack-app-vpc" "google_compute_network.main" "--quiet"
import_if_exists "compute health-checks" "fullstack-app-frontend-hc" "projects/$PROJECT_ID/global/healthChecks/fullstack-app-frontend-hc" "google_compute_health_check.frontend" "--quiet"
import_if_exists "compute health-checks" "fullstack-app-backend-hc" "projects/$PROJECT_ID/global/healthChecks/fullstack-app-backend-hc" "google_compute_health_check.backend" "--quiet"
import_if_exists "compute addresses" "fullstack-app-lb-ip" "projects/$PROJECT_ID/global/addresses/fullstack-app-lb-ip" "google_compute_global_address.default" "--global --quiet"

# Importer le service account s'il existe
if gcloud iam service-accounts describe fullstack-app-compute-sa@$PROJECT_ID.iam.gserviceaccount.com --project=$PROJECT_ID >/dev/null 2>&1; then
    echo " Importation du service account dans Terraform..."
    terraform import google_service_account.compute "projects/$PROJECT_ID/serviceAccounts/fullstack-app-compute-sa@$PROJECT_ID.iam.gserviceaccount.com" 2>/dev/null || echo " Service account déjà importé ou erreur d'import"
fi

echo " Planification Terraform..."
terraform plan \
    -var="environment=$ENVIRONMENT" \
    -var="project_id=$PROJECT_ID" \
    -var="region=$REGION" \
    -var="zone=$ZONE" \
    -var="db_password=${DB_PASSWORD:-SecurePassword123!}" \
    -out=tfplan-$ENVIRONMENT

echo " Application Terraform..."
terraform apply -auto-approve tfplan-$ENVIRONMENT

# Récupérer les outputs
LB_IP=$(terraform output -raw load_balancer_ip 2>/dev/null || echo "N/A")
MONITORING_IP=$(terraform output -raw monitoring_instance_ip 2>/dev/null || echo "N/A")

echo ""
echo " Déploiement terminé!"
echo "======================"
echo " URLs d'accès:"
echo "  - Application: http://$LB_IP"
echo "  - Grafana: http://$MONITORING_IP:3000 (admin/admin123)"
echo "  - Prometheus: http://$MONITORING_IP:9090"
echo ""

# Test automatique si pas en mode GitHub Actions
if [ -z "$GITHUB_ACTIONS" ]; then
    echo " Lancement des tests..."
    cd ..
    ./scripts/wait-and-test.sh
fi

cd ..
