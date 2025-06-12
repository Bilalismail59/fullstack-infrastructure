#!/bin/bash

# Script pour vérifier le progrès des scripts de démarrage
set -e

echo " VÉRIFICATION DU PROGRÈS DES SCRIPTS DE DÉMARRAGE"
echo "================================================="
echo ""

PROJECT_ID="primordial-port-462408-q7"

# Fonction pour vérifier une instance
check_instance() {
    local name=$1
    local zone=$2
    
    echo " Instance: $name"
    echo "Zone: $zone"
    
    # Récupérer les logs de la console série
    echo " Logs récents de démarrage:"
    gcloud compute instances get-serial-port-output $name \
        --zone $zone \
        --project $PROJECT_ID \
        --quiet 2>/dev/null | tail -30 | grep -E "(Started|Finished|Error|Failed|Installing|Configuring)" || echo "Aucun log de progression trouvé"
    
    echo ""
}

echo " Vérification de toutes les instances..."
gcloud compute instances list --project=$PROJECT_ID --format="value(name,zone)" | while read -r NAME ZONE; do
    if [[ "$NAME" == *"frontend"* ]] || [[ "$NAME" == *"backend"* ]]; then
        check_instance "$NAME" "$ZONE"
        echo "----------------------------------------"
    fi
done
