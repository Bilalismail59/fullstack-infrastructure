#!/bin/bash

# Script pour déployer après importation
set -e

PROJECT_ID=${GCP_PROJECT_ID:-"primordial-port-462408-q7"}
REGION=${GCP_REGION:-"europe-west1"}
ZONE="${REGION}-b"
ENVIRONMENT=${1:-prod}

echo " DÉPLOIEMENT APRÈS IMPORTATION"
echo "==============================="
echo "Environment: $ENVIRONMENT"
echo ""

# Étape 1: Importer toutes les ressources
echo " ÉTAPE 1: Importation des ressources..."
./scripts/import-all-resources.sh $ENVIRONMENT

# Étape 2: Déployer
echo " ÉTAPE 2: Déploiement..."
cd terraform

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

cd ..
