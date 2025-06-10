#!/bin/bash

# Script pour importer explicitement les ressources existantes dans l'état Terraform
set -e

PROJECT_ID=${GCP_PROJECT_ID:-"primordial-port-462408-q7"}
ENVIRONMENT=${1:-prod}

echo " Importation des ressources existantes dans Terraform"
echo "====================================================="
echo "Environment: $ENVIRONMENT"
echo "Project: $PROJECT_ID"
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
terraform init -reconfigure

# Supprimer l'état actuel et créer un nouvel état vide
echo " Réinitialisation de l'état Terraform..."
gsutil rm -f gs://$BUCKET_NAME/$ENVIRONMENT/terraform/state/default.tfstate || true
terraform state list >/dev/null 2>&1 || echo "État vide, prêt pour l'importation"

# Importer les ressources une par une avec -lock=false
echo " Importation des ressources..."

echo "1. Importation du VPC..."
terraform import -lock=false google_compute_network.main "projects/$PROJECT_ID/global/networks/fullstack-app-vpc" || echo " Erreur lors de l'importation du VPC"

echo "2. Importation du health check frontend..."
terraform import -lock=false google_compute_health_check.frontend "projects/$PROJECT_ID/global/healthChecks/fullstack-app-frontend-hc" || echo " Erreur lors de l'importation du health check frontend"

echo "3. Importation du health check backend..."
terraform import -lock=false google_compute_health_check.backend "projects/$PROJECT_ID/global/healthChecks/fullstack-app-backend-hc" || echo " Erreur lors de l'importation du health check backend"

echo "4. Importation de l'adresse globale..."
terraform import -lock=false google_compute_global_address.default "projects/$PROJECT_ID/global/addresses/fullstack-app-lb-ip" || echo " Erreur lors de l'importation de l'adresse globale"

echo "5. Importation du service account..."
terraform import -lock=false google_service_account.compute "projects/$PROJECT_ID/serviceAccounts/fullstack-app-compute-sa@$PROJECT_ID.iam.gserviceaccount.com" || echo " Erreur lors de l'importation du service account"

# Vérifier les sous-réseaux
echo "6. Importation des sous-réseaux..."
if gcloud compute networks subnets describe fullstack-app-web-subnet --region=europe-west1 --project=$PROJECT_ID >/dev/null 2>&1; then
    terraform import -lock=false google_compute_subnetwork.web "projects/$PROJECT_ID/regions/europe-west1/subnetworks/fullstack-app-web-subnet" || echo " Erreur lors de l'importation du sous-réseau web"
fi

if gcloud compute networks subnets describe fullstack-app-db-subnet --region=europe-west1 --project=$PROJECT_ID >/dev/null 2>&1; then
    terraform import -lock=false google_compute_subnetwork.db "projects/$PROJECT_ID/regions/europe-west1/subnetworks/fullstack-app-db-subnet" || echo " Erreur lors de l'importation du sous-réseau db"
fi

# Vérifier les règles de firewall
echo "7. Importation des règles de firewall..."
if gcloud compute firewall-rules describe fullstack-app-allow-http --project=$PROJECT_ID >/dev/null 2>&1; then
    terraform import -lock=false google_compute_firewall.allow_http "projects/$PROJECT_ID/global/firewalls/fullstack-app-allow-http" || echo " Erreur lors de l'importation de la règle firewall HTTP"
fi

if gcloud compute firewall-rules describe fullstack-app-allow-ssh --project=$PROJECT_ID >/dev/null 2>&1; then
    terraform import -lock=false google_compute_firewall.allow_ssh "projects/$PROJECT_ID/global/firewalls/fullstack-app-allow-ssh" || echo " Erreur lors de l'importation de la règle firewall SSH"
fi

if gcloud compute firewall-rules describe fullstack-app-allow-internal --project=$PROJECT_ID >/dev/null 2>&1; then
    terraform import -lock=false google_compute_firewall.allow_internal "projects/$PROJECT_ID/global/firewalls/fullstack-app-allow-internal" || echo " Erreur lors de l'importation de la règle firewall interne"
fi

if gcloud compute firewall-rules describe fullstack-app-allow-monitoring --project=$PROJECT_ID >/dev/null 2>&1; then
    terraform import -lock=false google_compute_firewall.allow_monitoring "projects/$PROJECT_ID/global/firewalls/fullstack-app-allow-monitoring" || echo " Erreur lors de l'importation de la règle firewall monitoring"
fi

echo " Importation terminée!"
echo "État Terraform actuel:"
terraform state list

echo ""
echo " Vous pouvez maintenant exécuter ./scripts/deploy-without-lock.sh $ENVIRONMENT"

cd ..
