#!/bin/bash

# Script de nettoyage pour supprimer toute l'infrastructure GCP
set -e

PROJECT_ID=${GCP_PROJECT_ID:-"primordial-port-462408-q7"}
ENVIRONMENT=${1:-preprod}

echo "🧹 Nettoyage de l'infrastructure GCP"
echo "Environment: $ENVIRONMENT"
echo "Project: $PROJECT_ID"
echo ""

# Confirmation de sécurité
if [ -z "$GITHUB_ACTIONS" ]; then
    read -p "  Êtes-vous sûr de vouloir supprimer toute l'infrastructure? (yes/no): " confirm
    if [ "$confirm" != "yes" ]; then
        echo " Opération annulée"
        exit 0
    fi
fi

echo " Authentification..."
if [ -f "terraform/service-account-key.json" ]; then
    gcloud auth activate-service-account --key-file=terraform/service-account-key.json
    gcloud config set project $PROJECT_ID
else
    echo " Fichier service-account-key.json non trouvé, utilisation des credentials actuels"
    # Vérifier si l'utilisateur est authentifié
    if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q "@"; then
        echo " Aucune authentification active. Exécutez 'gcloud auth login'"
        exit 1
    fi
fi

echo " Suppression via Terraform..."
cd terraform

# Configuration du backend
BUCKET_NAME="${PROJECT_ID}-terraform-state"
cat > backend.tf << EOF
terraform {
  backend "gcs" {
    bucket = "${BUCKET_NAME}"
    prefix = "${ENVIRONMENT}/terraform/state"
  }
}
EOF

# Initialiser Terraform
terraform init

# Vérifier si l'état existe
if terraform state list >/dev/null 2>&1; then
    echo " État Terraform trouvé, suppression des ressources..."
    terraform destroy -auto-approve \
        -var="environment=$ENVIRONMENT" \
        -var="project_id=$PROJECT_ID" \
        -var="region=europe-west1" \
        -var="zone=europe-west1-b" \
        -var="db_password=SecurePassword123!"
else
    echo " Aucun état Terraform trouvé, nettoyage manuel..."
    
    # Supprimer les instances de VM
    echo " Suppression des instances..."
    gcloud compute instances list --filter="name~'fullstack-app-'" --format="value(name,zone)" | while read -r NAME ZONE; do
        echo "Suppression de $NAME dans $ZONE..."
        gcloud compute instances delete $NAME --zone=$ZONE --quiet || true
    done
    
    # Supprimer les instance groups
    echo " Suppression des instance groups..."
    gcloud compute instance-groups managed list --filter="name~'fullstack-app-'" --format="value(name,region)" | while read -r NAME REGION; do
        echo "Suppression de $NAME dans $REGION..."
        gcloud compute instance-groups managed delete $NAME --region=$REGION --quiet || true
    done
    
    # Supprimer les instance templates
    echo " Suppression des instance templates..."
    gcloud compute instance-templates list --filter="name~'fullstack-app-'" --format="value(name)" | while read -r NAME; do
        echo "Suppression de $NAME..."
        gcloud compute instance-templates delete $NAME --quiet || true
    done
    
    # Supprimer les health checks
    echo " Suppression des health checks..."
    gcloud compute health-checks list --filter="name~'fullstack-app-'" --format="value(name)" | while read -r NAME; do
        echo "Suppression de $NAME..."
        gcloud compute health-checks delete $NAME --quiet || true
    done
    
    # Supprimer les load balancers
    echo " Suppression des load balancers..."
    gcloud compute forwarding-rules list --filter="name~'fullstack-app-'" --format="value(name)" | while read -r NAME; do
        echo "Suppression de $NAME..."
        gcloud compute forwarding-rules delete $NAME --global --quiet || true
    done
    
    # Supprimer les target proxies
    echo " Suppression des target proxies..."
    gcloud compute target-http-proxies list --filter="name~'fullstack-app-'" --format="value(name)" | while read -r NAME; do
        echo "Suppression de $NAME..."
        gcloud compute target-http-proxies delete $NAME --quiet || true
    done
    
    # Supprimer les URL maps
    echo " Suppression des URL maps..."
    gcloud compute url-maps list --filter="name~'fullstack-app-'" --format="value(name)" | while read -r NAME; do
        echo "Suppression de $NAME..."
        gcloud compute url-maps delete $NAME --quiet || true
    done
    
    # Supprimer les backend services
    echo " Suppression des backend services..."
    gcloud compute backend-services list --filter="name~'fullstack-app-'" --format="value(name)" | while read -r NAME; do
        echo "Suppression de $NAME..."
        gcloud compute backend-services delete $NAME --global --quiet || true
    done
    
    # Supprimer les addresses
    echo " Suppression des addresses..."
    gcloud compute addresses list --filter="name~'fullstack-app-'" --format="value(name,region)" | while read -r NAME REGION; do
        if [ -z "$REGION" ]; then
            echo "Suppression de l'adresse globale $NAME..."
            gcloud compute addresses delete $NAME --global --quiet || true
        else
            echo "Suppression de l'adresse régionale $NAME dans $REGION..."
            gcloud compute addresses delete $NAME --region=$REGION --quiet || true
        fi
    done
    
    # Supprimer les firewalls
    echo " Suppression des firewalls..."
    gcloud compute firewall-rules list --filter="name~'fullstack-app-'" --format="value(name)" | while read -r NAME; do
        echo "Suppression de $NAME..."
        gcloud compute firewall-rules delete $NAME --quiet || true
    done
    
    # Supprimer les subnetworks
    echo " Suppression des subnetworks..."
    gcloud compute networks subnets list --filter="name~'fullstack-app-'" --format="value(name,region)" | while read -r NAME REGION; do
        echo "Suppression de $NAME dans $REGION..."
        gcloud compute networks subnets delete $NAME --region=$REGION --quiet || true
    done
    
    # Supprimer les networks
    echo " Suppression des networks..."
    gcloud compute networks list --filter="name~'fullstack-app-'" --format="value(name)" | while read -r NAME; do
        echo "Suppression de $NAME..."
        gcloud compute networks delete $NAME --quiet || true
    done
    
    # Supprimer les instances Cloud SQL
    echo " Suppression des instances Cloud SQL..."
    gcloud sql instances list --filter="name~'fullstack-app-$ENVIRONMENT'" --format="value(name)" | while read -r NAME; do
        echo "Suppression de $NAME..."
        gcloud sql instances delete $NAME --quiet || true
    done
    
    # Supprimer les service accounts
    echo " Suppression des service accounts..."
    gcloud iam service-accounts list --filter="email~'fullstack-app-'" --format="value(email)" | while read -r EMAIL; do
        echo "Suppression de $EMAIL..."
        gcloud iam service-accounts delete $EMAIL --quiet || true
    done
fi

cd ..

echo " Infrastructure supprimée avec succès"
