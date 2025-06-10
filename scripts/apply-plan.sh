#!/bin/bash

# Script pour appliquer le plan Terraform
set -e

echo " APPLICATION DU PLAN TERRAFORM"
echo "==============================="

cd terraform

echo " Application du plan..."
terraform apply -auto-approve \
    -var="environment=prod" \
    -var="project_id=primordial-port-462408-q7" \
    -var="region=europe-west1" \
    -var="zone=europe-west1-b" \
    -var="db_password=SecurePassword123!"

# Récupérer les outputs
echo ""
echo " Récupération des informations de déploiement..."
LB_IP=$(terraform output -raw load_balancer_ip 2>/dev/null || echo "N/A")
MONITORING_IP=$(terraform output -raw monitoring_instance_ip 2>/dev/null || echo "N/A")

echo ""
echo " Déploiement terminé!"
echo "======================"
echo " URLs d'accès:"
echo "  - Application: http://$LB_IP"
echo "  - API Backend: http://$LB_IP/wp-json/wp/v2/posts"
echo "  - Grafana: http://$MONITORING_IP:3000 (admin/admin123)"
echo "  - Prometheus: http://$MONITORING_IP:9090"
echo ""
echo " Les nouvelles instances peuvent prendre 10-15 minutes pour être opérationnelles."
echo " Le load balancer peut prendre 5-10 minutes pour détecter les instances comme saines."

cd ..

echo ""
echo " Lancement du test automatique dans 2 minutes..."
sleep 120
./scripts/wait-and-test.sh $LB_IP $MONITORING_IP
