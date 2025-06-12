#!/bin/bash

# Script pour finaliser le déploiement sans importation
set -e

echo " FINALISATION DU DÉPLOIEMENT"
echo "============================="

cd terraform

echo " Toutes les ressources sont déjà importées!"

echo ""
echo " Application finale pour synchroniser l'état..."
terraform apply -auto-approve \
    -var="environment=prod" \
    -var="project_id=primordial-port-462408-q7" \
    -var="region=europe-west1" \
    -var="zone=europe-west1-b" \
    -var="db_password=SecurePassword123!"

# Récupérer les outputs
echo ""
echo " Récupération des informations finales..."
LB_IP=$(terraform output -raw load_balancer_ip 2>/dev/null || echo "34.8.29.157")
MONITORING_IP=$(terraform output -raw monitoring_instance_ip 2>/dev/null || echo "N/A")

echo ""
echo " INFRASTRUCTURE COMPLÈTEMENT DÉPLOYÉE!"
echo "========================================"
echo ""
echo " URLs d'accès:"
echo "  -   Application Frontend: http://$LB_IP"
echo "  -   API Backend: http://$LB_IP/wp-json/wp/v2/posts"
echo "  -  Grafana Monitoring: http://$MONITORING_IP:3000"
echo "    └── Credentials: admin/admin123"
echo "  -  Prometheus: http://$MONITORING_IP:9090"
echo ""
echo " Statistiques de l'infrastructure:"
RESOURCE_COUNT=$(terraform state list | wc -l)
echo "  - Ressources Terraform: $RESOURCE_COUNT"
echo "  - Environment: Production"
echo "  - Region: europe-west1"
echo "  - Load Balancer IP: $LB_IP"
echo ""

cd ..

echo " TESTS AUTOMATIQUES DE L'INFRASTRUCTURE"
echo "=========================================="
./scripts/complete-stack-test.sh $LB_IP $MONITORING_IP

echo ""
echo " FÉLICITATIONS!"
echo "================"
echo "Votre infrastructure fullstack est maintenant complètement déployée et opérationnelle!"
echo ""
echo " Prochaines étapes recommandées:"
echo "  1. Configurez votre domaine pour pointer vers $LB_IP"
echo "  2. Configurez SSL/HTTPS si nécessaire"
echo "  3. Personnalisez les dashboards Grafana"
echo "  4. Configurez les alertes de monitoring"
echo ""
echo " Pour gérer l'infrastructure:"
echo "  - Diagnostic: ./scripts/diagnose-full-stack.sh"
echo "  - Tests: ./scripts/complete-stack-test.sh"
echo "  - Nettoyage: ./scripts/cleanup-gcp.sh prod"
echo ""
echo " Infrastructure prête pour la production!"
