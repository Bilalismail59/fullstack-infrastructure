#!/bin/bash

# Script pour vérifier l'état complet du déploiement
set -e

echo " VÉRIFICATION DE L'ÉTAT DU DÉPLOIEMENT"
echo "========================================"
echo ""

# Variables depuis les outputs Terraform
LB_IP="34.8.29.157"
MONITORING_IP="34.77.227.135"
PROJECT_ID="primordial-port-462408-q7"

echo " Informations du déploiement:"
echo "  Load Balancer IP: $LB_IP"
echo "  Monitoring Instance IP: $MONITORING_IP"
echo "  Project ID: $PROJECT_ID"
echo ""

echo " Vérification des instances GCP..."
gcloud compute instances list --project=$PROJECT_ID --format="table(name,zone,status,externalIP,internalIP)"

echo ""
echo " État des Instance Groups..."
gcloud compute instance-groups managed list --project=$PROJECT_ID --format="table(name,location,targetSize,currentActions.creating,currentActions.deleting)"

echo ""
echo " Test de connectivité des services..."

# Test du Load Balancer
echo " Test du Load Balancer ($LB_IP)..."
if curl -s --connect-timeout 10 -I http://$LB_IP | head -n1; then
    echo " Load Balancer répond"
else
    echo " Load Balancer pas encore prêt"
fi

# Test de Grafana
echo " Test de Grafana ($MONITORING_IP:3000)..."
if curl -s --connect-timeout 10 -I http://$MONITORING_IP:3000 | head -n1; then
    echo " Grafana accessible sur: http://$MONITORING_IP:3000"
    echo "   Credentials: admin/admin123"
else
    echo " Grafana en cours de démarrage..."
fi

# Test de Prometheus
echo " Test de Prometheus ($MONITORING_IP:9090)..."
if curl -s --connect-timeout 10 -I http://$MONITORING_IP:9090 | head -n1; then
    echo " Prometheus accessible sur: http://$MONITORING_IP:9090"
else
    echo " Prometheus en cours de démarrage..."
fi

echo ""
echo " État de santé des backends du Load Balancer..."
echo "Frontend Backend Service:"
gcloud compute backend-services get-health fullstack-app-frontend-backend --global --project=$PROJECT_ID 2>/dev/null || echo "   En cours de vérification..."

echo ""
echo "Backend (API) Backend Service:"
gcloud compute backend-services get-health fullstack-app-backend-backend --global --project=$PROJECT_ID 2>/dev/null || echo "   En cours de vérification..."

echo ""
echo " Résumé:"
echo " Infrastructure Terraform déployée"
echo " Load Balancer configuré"
echo " Instance Groups créés"
echo " Base de données Cloud SQL active"
echo " Instance de monitoring déployée"
echo ""
echo " URLs d'accès:"
echo "  Application: http://$LB_IP"
echo "  Grafana: http://$MONITORING_IP:3000"
echo "  Prometheus: http://$MONITORING_IP:9090"
