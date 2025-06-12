#!/bin/bash

# Script pour forcer le redémarrage des services web sur les instances
set -e

echo " REDÉMARRAGE FORCÉ DES SERVICES WEB"
echo "===================================="
echo ""

PROJECT_ID="primordial-port-462408-q7"

# Fonction pour redémarrer les services sur une instance
restart_services() {
    local name=$1
    local zone=$2
    local type=$3
    
    echo " Redémarrage des services sur: $name ($type)"
    
    if [[ "$type" == *"frontend"* ]]; then
        echo "Frontend - Redémarrage Nginx et Node.js..."
        gcloud compute ssh $name --zone=$zone --project=$PROJECT_ID --command="
            sudo systemctl restart nginx || echo 'Nginx non disponible'
            sudo pm2 restart all || echo 'PM2 non disponible'
            sudo systemctl restart node_exporter || echo 'Node exporter non disponible'
            
            # Vérifier les ports
            echo 'Ports en écoute après redémarrage:'
            sudo netstat -tlnp | grep ':80' || echo 'Port 80 non en écoute'
            sudo netstat -tlnp | grep ':3000' || echo 'Port 3000 non en écoute'
        " --quiet 2>/dev/null || echo " Impossible de se connecter à $name"
        
    elif [[ "$type" == *"backend"* ]]; then
        echo "Backend - Redémarrage Apache..."
        gcloud compute ssh $name --zone=$zone --project=$PROJECT_ID --command="
            sudo systemctl restart apache2 || echo 'Apache non disponible'
            sudo systemctl restart node_exporter || echo 'Node exporter non disponible'
            
            # Vérifier les ports
            echo 'Ports en écoute après redémarrage:'
            sudo netstat -tlnp | grep ':80' || echo 'Port 80 non en écoute'
        " --quiet 2>/dev/null || echo " Impossible de se connecter à $name"
    fi
    
    echo ""
}

echo " Redémarrage des services sur toutes les instances..."
gcloud compute instances list --project=$PROJECT_ID --format="value(name,zone)" | while read -r NAME ZONE; do
    if [[ "$NAME" == *"frontend"* ]]; then
        restart_services "$NAME" "$ZONE" "frontend"
    elif [[ "$NAME" == *"backend"* ]]; then
        restart_services "$NAME" "$ZONE" "backend"
    fi
done

echo " Redémarrage terminé. Attendez 2-3 minutes puis testez à nouveau."
