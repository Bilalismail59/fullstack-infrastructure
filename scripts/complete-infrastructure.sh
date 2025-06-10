#!/bin/bash

# Script pour déployer l'infrastructure complète (preprod et prod avec Kubernetes)
set -e

echo " Déploiement de l'infrastructure complète (preprod et prod avec Kubernetes)"
echo "  ATTENTION: Ceci va créer des ressources dans les environnements de preprod ET prod"
read -p "Êtes-vous sûr de vouloir continuer? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo " Déploiement annulé"
    exit 0
fi

# 1. Déployer l'environnement de préproduction
echo " Déploiement de l'environnement de PRÉPRODUCTION..."
cd terraform
export GOOGLE_APPLICATION_CREDENTIALS="$(pwd)/service-account-key.json"

terraform plan \
    -var="environment=preprod" \
    -var="project_id=primordial-port-462408-q7" \
    -var="region=europe-west1" \
    -var="zone=europe-west1-b" \
    -var="db_password=SecurePassword123!" \
    -out=tfplan-preprod

terraform apply -auto-approve tfplan-preprod
cd ..

# 2. Créer le cluster Kubernetes pour la préproduction
echo " Création du cluster Kubernetes pour la PRÉPRODUCTION..."
./scripts/create-gke-cluster.sh preprod

# 3. Déployer les applications sur Kubernetes (préproduction)
echo " Déploiement des applications sur Kubernetes (PRÉPRODUCTION)..."
./scripts/deploy-to-kubernetes.sh preprod

# 4. Déployer l'environnement de production
echo " Déploiement de l'environnement de PRODUCTION..."
cd terraform
terraform plan \
    -var="environment=prod" \
    -var="project_id=primordial-port-462408-q7" \
    -var="region=europe-west1" \
    -var="zone=europe-west1-b" \
    -var="db_password=SecurePassword123!" \
    -out=tfplan-prod

terraform apply -auto-approve tfplan-prod
cd ..

# 5. Créer le cluster Kubernetes pour la production
echo " Création du cluster Kubernetes pour la PRODUCTION..."
./scripts/create-gke-cluster.sh prod

# 6. Déployer les applications sur Kubernetes (production)
echo " Déploiement des applications sur Kubernetes (PRODUCTION)..."
./scripts/deploy-to-kubernetes.sh prod

echo " Déploiement de l'infrastructure complète terminé!"
echo ""
echo " Résumé:"
echo "   Environnement de PRÉPRODUCTION déployé"
echo "   Cluster Kubernetes de PRÉPRODUCTION créé"
echo "   Applications déployées sur Kubernetes (PRÉPRODUCTION)"
echo "   Environnement de PRODUCTION déployé"
echo "   Cluster Kubernetes de PRODUCTION créé"
echo "   Applications déployées sur Kubernetes (PRODUCTION)"
