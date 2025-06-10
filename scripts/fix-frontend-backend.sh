#!/bin/bash

# Script pour corriger et redémarrer frontend et backend
set -e

PROJECT_ID="primordial-port-462408-q7"
REGION="europe-west1"

echo " CORRECTION ET REDÉMARRAGE FRONTEND/BACKEND"
echo "============================================="

# 1. Recréer les instance templates avec des scripts corrigés
echo " 1. Création de nouveaux templates d'instances..."

# Template Frontend corrigé
gcloud compute instance-templates create fullstack-app-frontend-fixed \
    --project=$PROJECT_ID \
    --machine-type=e2-medium \
    --image-family=ubuntu-2004-lts \
    --image-project=ubuntu-os-cloud \
    --boot-disk-size=20GB \
    --boot-disk-type=pd-standard \
    --network=fullstack-app-vpc \
    --subnet=fullstack-app-web-subnet \
    --tags=web-server,frontend \
    --metadata-from-file=startup-script=terraform/startup-scripts/frontend-fixed.sh \
    --service-account=fullstack-app-compute-sa@$PROJECT_ID.iam.gserviceaccount.com \
    --scopes=cloud-platform

# Template Backend corrigé
gcloud compute instance-templates create fullstack-app-backend-fixed \
    --project=$PROJECT_ID \
    --machine-type=e2-medium \
    --image-family=ubuntu-2004-lts \
    --image-project=ubuntu-os-cloud \
    --boot-disk-size=20GB \
    --boot-disk-type=pd-standard \
    --network=fullstack-app-vpc \
    --subnet=fullstack-app-web-subnet \
    --tags=web-server,backend \
    --metadata-from-file=startup-script=terraform/startup-scripts/backend-fixed.sh \
    --service-account=fullstack-app-compute-sa@$PROJECT_ID.iam.gserviceaccount.com \
    --scopes=cloud-platform

# 2. Mettre à jour les Instance Groups avec les nouveaux templates
echo " 2. Mise à jour des Instance Groups..."

# Mettre à jour le frontend
gcloud compute instance-groups managed set-instance-template fullstack-app-frontend-mig \
    --template=fullstack-app-frontend-fixed \
    --region=$REGION \
    --project=$PROJECT_ID

# Mettre à jour le backend
gcloud compute instance-groups managed set-instance-template fullstack-app-backend-mig \
    --template=fullstack-app-backend-fixed \
    --region=$REGION \
    --project=$PROJECT_ID

# 3. Rolling restart des instances
echo " 3. Rolling restart des instances..."

# Rolling restart frontend
gcloud compute instance-groups managed rolling-action start-update fullstack-app-frontend-mig \
    --version=template=fullstack-app-frontend-fixed \
    --region=$REGION \
    --project=$PROJECT_ID

# Rolling restart backend
gcloud compute instance-groups managed rolling-action start-update fullstack-app-backend-mig \
    --version=template=fullstack-app-backend-fixed \
    --region=$REGION \
    --project=$PROJECT_ID

echo " Mise à jour lancée! Attendez 10-15 minutes que les nouvelles instances démarrent."
