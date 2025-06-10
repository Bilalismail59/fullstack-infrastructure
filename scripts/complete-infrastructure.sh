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
gsutil mb -p $PROJECT_ID -c STANDARD -l $REGION gs://$BUCKET_NAME/ 2>/dev/null || echo "✅ Bucket state existe déjà"
gsutil versioning set on gs://$BUCKET_NAME/

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

echo " Planification Terraform..."
terraform plan \
    -var="environment=$ENVIRONMENT" \
    -var="project_id=$PROJECT_ID" \
    -var="region=$REGION" \
    -var="zone=$ZONE" \
    -var="db_password=SecurePassword123!" \
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
