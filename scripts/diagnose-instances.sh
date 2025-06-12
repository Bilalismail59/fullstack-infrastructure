#!/bin/bash

# Script pour diagnostiquer les problèmes des instances
set -e

echo " DIAGNOSTIC DES INSTANCES"
echo "=========================="
echo ""

PROJECT_ID="primordial-port-462408-q7"

echo " Récupération des instances..."
INSTANCES=$(gcloud compute instances list --project=$PROJECT_ID --format="csv(name,zone,status)" --quiet | tail -n +2)

echo "$INSTANCES" | while IFS=',' read -r NAME ZONE STATUS; do
    if [[ "$NAME" == *"frontend"* ]] || [[ "$NAME" == *"backend"* ]]; then
        echo ""
        echo " Diagnostic de l'instance: $NAME"
        echo "Zone: $ZONE, Status: $STATUS"
        echo "----------------------------------------"
        
        # Vérifier si l'instance répond au SSH
        echo " Test de connectivité SSH..."
        if gcloud compute ssh $NAME --zone=$ZONE --project=$PROJECT_ID --command="echo 'SSH OK'" --quiet 2>/dev/null; then
            echo " SSH accessible"
            
            # Vérifier les services web
            echo " Vérification des services web..."
            gcloud compute ssh $NAME --zone=$ZONE --project=$PROJECT_ID --command="
                echo '--- État des services ---'
                sudo systemctl status apache2 2>/dev/null || echo 'Apache non installé/démarré'
                sudo systemctl status nginx 2>/dev/null || echo 'Nginx non installé/démarré'
                
                echo '--- Processus en cours ---'
                ps aux | grep -E '(apache|nginx|node|npm)' | grep -v grep || echo 'Aucun service web détecté'
                
                echo '--- Ports en écoute ---'
                sudo netstat -tlnp | grep ':80' || echo 'Port 80 non en écoute'
                
                echo '--- Logs de démarrage récents ---'
                tail -20 /var/log/cloud-init-output.log 2>/dev/null || echo 'Logs cloud-init non disponibles'
            " --quiet 2>/dev/null
        else
            echo " SSH non accessible - instance peut-être en cours de démarrage"
        fi
        echo "----------------------------------------"
    fi
done
