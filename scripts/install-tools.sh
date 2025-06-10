#!/bin/bash

# Script d'installation des outils requis
set -e

echo " Installation des outils requis pour GCP Full Stack Infrastructure"

# Fonction pour vérifier si une commande existe
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Mise à jour du système
echo " Mise à jour du système..."
sudo apt update && sudo apt upgrade -y

# Installation des dépendances de base
echo "🔧 Installation des dépendances de base..."
sudo apt install -y \
    curl \
    wget \
    gnupg \
    lsb-release \
    apt-transport-https \
    ca-certificates \
    software-properties-common \
    unzip \
    git \
    python3 \
    python3-pip \
    jq

# Installation de Google Cloud CLI
if ! command_exists gcloud; then
    echo " Installation de Google Cloud CLI..."
    curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg
    echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
    sudo apt update
    sudo apt install -y google-cloud-cli
    echo " Google Cloud CLI installé avec succès"
else
    echo " Google Cloud CLI déjà installé"
fi

# Installation de Terraform
if ! command_exists terraform; then
    echo " Installation de Terraform..."
    wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
    sudo apt update
    sudo apt install -y terraform
    echo " Terraform installé avec succès"
else
    echo " Terraform déjà installé"
fi

# Installation de kubectl
if ! command_exists kubectl; then
    echo " Installation de kubectl..."
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    rm kubectl
    echo " kubectl installé avec succès"
else
    echo " kubectl déjà installé"
fi

# Installation de Node.js
if ! command_exists node; then
    echo " Installation de Node.js..."
    curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
    sudo apt install -y nodejs
    echo " Node.js installé avec succès"
else
    echo " Node.js déjà installé"
fi

echo ""
echo " Installation terminée!"
echo ""
echo " Prochaines étapes:"
echo "1. Configurez gcloud: gcloud auth login"
echo "2. Exécutez le déploiement: ./scripts/complete-infrastructure.sh"
