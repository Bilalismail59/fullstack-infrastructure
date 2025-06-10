#!/bin/bash

# Script pour tester la connexion à la base de données
set -e

PROJECT_ID="primordial-port-462408-q7"

echo " TEST DE CONNEXION À LA BASE DE DONNÉES"
echo "========================================="

# Récupérer les informations de la base de données
echo " Informations de la base de données:"
gcloud sql instances describe fullstack-app-preprod-db --project=$PROJECT_ID --format="table(name,state,ipAddresses[0].ipAddress,databaseVersion)"

# Récupérer l'IP privée
DB_IP=$(gcloud sql instances describe fullstack-app-preprod-db --project=$PROJECT_ID --format="value(ipAddresses[0].ipAddress)")
echo " IP de la base de données: $DB_IP"

# Tester la connexion depuis une instance backend
echo " Test de connexion depuis les instances backend..."
BACKEND_INSTANCES=$(gcloud compute instances list --filter="name~backend" --format="value(name,zone)")

if [ -n "$BACKEND_INSTANCES" ]; then
    echo "$BACKEND_INSTANCES" | while read -r NAME ZONE; do
        if [ -n "$NAME" ] && [ -n "$ZONE" ]; then
            echo "Testing connection from $NAME..."
            gcloud compute ssh $NAME --zone=$ZONE --project=$PROJECT_ID --command="
                mysql -h $DB_IP -u wordpress -pSecurePassword123! -e 'SELECT VERSION();' wordpress
            " || echo " Connection failed from $NAME"
        fi
    done
else
    echo " Aucune instance backend trouvée"
fi

echo " Test de connexion terminé"
