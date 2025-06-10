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

# FORCER LA RÉINITIALISATION DE L'ÉTAT ET IMPORTATION
echo " Réinitialisation forcée de l'état Terraform..."
gsutil rm -f gs://$BUCKET_NAME/$ENVIRONMENT/terraform/state/default.tfstate* || true

echo " Réinitialisation du backend..."
terraform init -reconfigure

echo " IMPORTATION FORCÉE des ressources existantes..."

# Importer les ressources une par une
echo "1. Import VPC..."
terraform import google_compute_network.main "projects/$PROJECT_ID/global/networks/fullstack-app-vpc" || echo " VPC import failed"

echo "2. Import Health Check Frontend..."
terraform import google_compute_health_check.frontend "projects/$PROJECT_ID/global/healthChecks/fullstack-app-frontend-hc" || echo " Frontend HC import failed"

echo "3. Import Health Check Backend..."
terraform import google_compute_health_check.backend "projects/$PROJECT_ID/global/healthChecks/fullstack-app-backend-hc" || echo " Backend HC import failed"

echo "4. Import Global Address..."
terraform import google_compute_global_address.default "projects/$PROJECT_ID/global/addresses/fullstack-app-lb-ip" || echo " Address import failed"

echo "5. Import Service Account..."
terraform import google_service_account.compute "projects/$PROJECT_ID/serviceAccounts/fullstack-app-compute-sa@$PROJECT_ID.iam.gserviceaccount.com" || echo " SA import failed"

# Importer les sous-réseaux s'ils existent
echo "6. Import Subnets..."
if gcloud compute networks subnets describe fullstack-app-web-subnet --region=$REGION --project=$PROJECT_ID >/dev/null 2>&1; then
    terraform import google_compute_subnetwork.web "projects/$PROJECT_ID/regions/$REGION/subnetworks/fullstack-app-web-subnet" || echo " Web subnet import failed"
fi

if gcloud compute networks subnets describe fullstack-app-db-subnet --region=$REGION --project=$PROJECT_ID >/dev/null 2>&1; then
    terraform import google_compute_subnetwork.db "projects/$PROJECT_ID/regions/$REGION/subnetworks/fullstack-app-db-subnet" || echo " DB subnet import failed"
fi

# Importer les règles de firewall s'elles existent
echo "7. Import Firewall Rules..."
if gcloud compute firewall-rules describe fullstack-app-allow-http --project=$PROJECT_ID >/dev/null 2>&1; then
    terraform import google_compute_firewall.allow_http "projects/$PROJECT_ID/global/firewalls/fullstack-app-allow-http" || echo " HTTP firewall import failed"
fi

if gcloud compute firewall-rules describe fullstack-app-allow-ssh --project=$PROJECT_ID >/dev/null 2>&1; then
    terraform import google_compute_firewall.allow_ssh "projects/$PROJECT_ID/global/firewalls/fullstack-app-allow-ssh" || echo " SSH firewall import failed"
fi

if gcloud compute firewall-rules describe fullstack-app-allow-internal --project=$PROJECT_ID >/dev/null 2>&1; then
    terraform import google_compute_firewall.allow_internal "projects/$PROJECT_ID/global/firewalls/fullstack-app-allow-internal" || echo " Internal firewall import failed"
fi

if gcloud compute firewall-rules describe fullstack-app-allow-monitoring --project=$PROJECT_ID >/dev/null 2>&1; then
    terraform import google_compute_firewall.allow_monitoring "projects/$PROJECT_ID/global/firewalls/fullstack-app-allow-monitoring" || echo " Monitoring firewall import failed"
fi

# Importer les adresses privées s'elles existent
echo "8. Import Private IP Address..."
if gcloud compute addresses describe fullstack-app-private-ip --global --project=$PROJECT_ID >/dev/null 2>&1; then
    terraform import google_compute_global_address.private_ip_address "projects/$PROJECT_ID/global/addresses/fullstack-app-private-ip" || echo " Private IP import failed"
fi

echo " Importation terminée!"
echo "État Terraform actuel:"
terraform state list

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
