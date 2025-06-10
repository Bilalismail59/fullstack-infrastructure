#!/bin/bash

# Script pour attendre et tester périodiquement
set -e

LB_IP="34.8.29.157"
MAX_ATTEMPTS=20
ATTEMPT=1

echo " Attente que la stack soit complètement opérationnelle..."
echo "Cela peut prendre jusqu'à 20 minutes."
echo ""

while [ $ATTEMPT -le $MAX_ATTEMPTS ]; do
    echo " Tentative $ATTEMPT/$MAX_ATTEMPTS - $(date)"
    
    # Test frontend
    if curl -s --connect-timeout 10 http://$LB_IP >/dev/null 2>&1; then
        echo " Frontend opérationnel!"
        
        # Test backend
        if curl -s --connect-timeout 10 http://$LB_IP/api/wp-json/wp/v2/posts >/dev/null 2>&1; then
            echo " Backend opérationnel!"
            echo ""
            echo " Stack complètement opérationnelle!"
            ./scripts/complete-stack-test.sh
            exit 0
        else
            echo " Backend encore en cours de démarrage..."
        fi
    else
        echo " Frontend encore en cours de démarrage..."
    fi
    
    echo "   Prochaine vérification dans 60 secondes..."
    echo ""
    sleep 60
    ((ATTEMPT++))
done

echo " Timeout atteint. Vérification manuelle recommandée."
./scripts/diagnose-full-stack.sh
