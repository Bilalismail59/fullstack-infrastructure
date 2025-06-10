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

# ÉTAPE 1: Importer les ressources existantes
echo " ÉTAPE 1: Importation des ressources existantes..."
./scripts/import-existing-resources.sh $ENVIRONMENT

# ÉTAPE 2: Déployer l'infrastructure
echo " ÉTAPE 2: Déploiement de l'infrastructure..."
cd terraform

# Configuration des credentials selon l'environnement
if [ -n "$GITHUB_ACTIONS" ]; then
  echo " Configuration GitHub Actions..."
  export GOOGLE_APPLICATION_CREDENTIALS="$(pwd)/service-account-key.json"
  gcloud auth activate-service-account --key-file=service-account-key.json
  gcloud config set project $PROJECT_ID
else
  echo " Configuration locale..."
  # Vérifier l'authentification
  if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q "@"; then
      echo " Non authentifié. Exécutez: gcloud auth login"
      exit 1
  fi
  
  # Utiliser la clé de service déjà créée
  export GOOGLE_APPLICATION_CREDENTIALS="$(pwd)/service-account-key.json"
  gcloud config set project $PROJECT_ID
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
terraform apply tfplan-$ENVIRONMENT

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
