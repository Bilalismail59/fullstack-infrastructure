#!/bin/bash

# Script pour corriger la configuration du Load Balancer
set -e

PROJECT_ID="primordial-port-462408-q7"

echo " CORRECTION DU LOAD BALANCER"
echo "=============================="

# 1. Vérifier l'état actuel des health checks
echo " Vérification des health checks..."
gcloud compute health-checks describe fullstack-app-frontend-hc --global --project=$PROJECT_ID
gcloud compute health-checks describe fullstack-app-backend-hc --global --project=$PROJECT_ID

# 2. Mettre à jour les health checks pour être plus permissifs
echo " Mise à jour des health checks..."

# Health check frontend plus permissif
gcloud compute health-checks update http fullstack-app-frontend-hc \
    --global \
    --project=$PROJECT_ID \
    --port=80 \
    --request-path="/health" \
    --check-interval=30s \
    --timeout=10s \
    --healthy-threshold=2 \
    --unhealthy-threshold=5

# Health check backend plus permissif
gcloud compute health-checks update http fullstack-app-backend-hc \
    --global \
    --project=$PROJECT_ID \
    --port=80 \
    --request-path="/health" \
    --check-interval=30s \
    --timeout=10s \
    --healthy-threshold=2 \
    --unhealthy-threshold=5

# 3. Vérifier l'état des backend services
echo " État des backend services..."
gcloud compute backend-services get-health fullstack-app-frontend-backend --global --project=$PROJECT_ID
gcloud compute backend-services get-health fullstack-app-backend-backend --global --project=$PROJECT_ID

echo " Configuration du Load Balancer mise à jour"
echo " Attendez 5-10 minutes que les health checks se stabilisent"
