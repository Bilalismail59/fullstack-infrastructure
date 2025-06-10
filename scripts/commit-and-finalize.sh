#!/bin/bash

# Script pour commiter proprement et finaliser
set -e

echo " COMMIT PROPRE ET FINALISATION"
echo "==============================="

# Créer le .gitignore s'il n'existe pas
if [ ! -f ".gitignore" ]; then
    echo " Création du .gitignore..."
    # Le .gitignore sera créé par le CodeProject
fi

echo " Nettoyage des fichiers sensibles..."
# S'assurer que les fichiers sensibles ne sont pas trackés
git rm --cached terraform/service-account-key.json 2>/dev/null || true
git rm --cached terraform/*.tfstate* 2>/dev/null || true
git rm --cached terraform/tfplan* 2>/dev/null || true

echo " Ajout des fichiers utiles..."
# Ajouter seulement les fichiers utiles
git add .gitignore
git add scripts/
git add terraform/main.tf
git add terraform/variables.tf
git add terraform/outputs.tf
git add terraform/startup-scripts/
git add ansible/
git add monitoring/
git add k8s/
git add docker-compose.yml
git add README.md
git add .github/

echo " Commit des changements..."
git commit -m " Infrastructure complète avec scripts de déploiement

 Ajout de tous les scripts de déploiement et gestion
 Configuration Terraform complète
 Scripts d'importation et de finalisation
 Monitoring et observabilité
 Documentation mise à jour
 .gitignore pour la sécurité

Infrastructure prête pour déploiement en prod/preprod"

echo " Commit terminé!"

echo ""
echo " Maintenant, finalisation du déploiement..."
./scripts/final-import-and-complete.sh
