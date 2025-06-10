#!/bin/bash

# Script pour configurer l'authentification GCP
set -e

echo " Configuration de l'authentification GCP"
echo "========================================"

# Authentification avec gcloud
echo " Authentification avec gcloud..."
gcloud auth login

# Configuration de l'authentification par défaut (ADC)
echo " Configuration de l'authentification par défaut..."
gcloud auth application-default login

echo " Authentification configurée avec succès!"
echo ""
echo "Vous pouvez maintenant exécuter:"
echo "  ./scripts/simple-unlock.sh"
