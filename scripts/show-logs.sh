#!/bin/bash

# Script pour afficher les logs des instances
set -e

echo " AFFICHAGE DES LOGS DES INSTANCES"
echo "=================================="
echo ""

PROJECT_ID="primordial-port-462408-q7"

echo " Récupération de la liste des instances..."
INSTANCES=$(gcloud compute instances list --project=$PROJECT_ID --format="value(name,zone)")

if [ -z "$INSTANCES" ]; then
    echo " Aucune instance trouvée"
    exit 1
fi

echo "$INSTANCES" | while read -r NAME ZONE; do
    if [ -n "$NAME" ] && [ -n "$ZONE" ]; then
        echo ""
        echo " Logs de l'instance: $NAME (Zone: $ZONE)"
        echo "----------------------------------------"
        
        # Afficher les dernières lignes du log de démarrage
        echo " Script de démarrage (dernières 30 lignes):"
        gcloud compute instances get-serial-port-output $NAME \
            --zone $ZONE \
            --project $PROJECT_ID \
            --quiet 2>/dev/null | tail -n 30 || echo "Logs non disponibles"
        
        echo "----------------------------------------"
    fi
done

echo ""
echo " Pour voir les logs en temps réel d'une instance:"
echo "gcloud compute instances get-serial-port-output INSTANCE_NAME --zone ZONE --project $PROJECT_ID"
