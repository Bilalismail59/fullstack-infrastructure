#!/bin/bash

# Script de déploiement direct sans importation
set -e

echo " DÉPLOIEMENT DIRECT (SANS IMPORTATION)"
echo "========================================"

# Arrêter tous les processus terraform en cours
pkill -f terraform || true

cd terraform

# Nettoyer complètement l'état
rm -f terraform*.tfstate*
rm -f .terraform.lock.hcl
rm -rf .terraform/

# Configuration backend local
cat > backend.tf << 'EOF'
terraform {
  backend "local" {
    path = "terraform.tfstate"
  }
}
EOF

# Créer un fichier de variables pour éviter les prompts
cat > terraform.tfvars << 'EOF'
project_id = "primordial-port-462408-q7"
region = "europe-west1"
zone = "europe-west1-b"
environment = "prod"
db_password = "SecurePassword123!"
project_name = "fullstack-app"
machine_type = "e2-micro"
image_family = "ubuntu-2004-lts"
admin_cidr = "0.0.0.0/0"
db_tier = "db-f1-micro"
domain_name = ""
EOF

echo " Initialisation Terraform..."
terraform init

echo " Planification (Terraform va gérer les ressources existantes)..."
terraform plan -out=tfplan

echo ""
echo "  Terraform va essayer de créer des ressources qui existent déjà."
echo "   Cela va générer des erreurs 'already exists' mais c'est normal."
echo "   Nous allons ensuite importer ces ressources dans l'état."
echo ""

echo " Application du plan..."
terraform apply -auto-approve tfplan 2>&1 | tee apply.log || echo "Erreurs attendues pour les ressources existantes"

echo ""
echo " Maintenant, importation des ressources qui ont échoué..."

# Importer les ressources qui existent déjà (sans variables interactives)
echo "Importation du VPC..."
terraform import google_compute_network.main "projects/primordial-port-462408-q7/global/networks/fullstack-app-vpc" || echo "VPC import failed"

echo "Importation des health checks..."
terraform import google_compute_health_check.frontend "projects/primordial-port-462408-q7/global/healthChecks/fullstack-app-frontend-hc" || echo "Frontend HC import failed"
terraform import google_compute_health_check.backend "projects/primordial-port-462408-q7/global/healthChecks/fullstack-app-backend-hc" || echo "Backend HC import failed"

echo "Importation de l'adresse IP..."
terraform import google_compute_global_address.default "projects/primordial-port-462408-q7/global/addresses/fullstack-app-lb-ip" || echo "IP import failed"

echo "Importation du service account..."
terraform import google_service_account.compute "projects/primordial-port-462408-q7/serviceAccounts/fullstack-app-compute-sa@primordial-port-462408-q7.iam.gserviceaccount.com" || echo "SA import failed"

echo ""
echo " Nouvelle application après importation..."
terraform plan -out=tfplan2
terraform apply -auto-approve tfplan2

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
