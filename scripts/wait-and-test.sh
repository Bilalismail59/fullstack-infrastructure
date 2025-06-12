#!/bin/bash

# Script pour attendre et tester périodiquement les services
set -e

echo " ATTENTE ET TEST PÉRIODIQUE DES SERVICES"
echo "========================================="
echo ""

LB_IP="34.8.29.157"
MONITORING_IP="34.77.227.135"
MAX_ATTEMPTS=20
WAIT_TIME=30

test_service() {
    local url=$1
    local name=$2
    
    response=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 10 --max-time 30 "$url" 2>/dev/null || echo "000")
    
    if [ "$response" = "200" ]; then
        echo " $name: OK"
        return 0
    else
        echo " $name: HTTP $response (en attente...)"
        return 1
    fi
}

for attempt in $(seq 1 $MAX_ATTEMPTS); do
    echo " Tentative $attempt/$MAX_ATTEMPTS ($(date))"
    
    # Test du Load Balancer
    if test_service "http://$LB_IP" "Load Balancer"; then
        echo " Load Balancer est maintenant accessible !"
        break
    fi
    
    # Vérifier l'état des backends
    echo " État des backends:"
    gcloud compute backend-services get-health fullstack-app-frontend-backend --global --project=primordial-port-462408-q7 --format="value(status.healthStatus[].healthState)" 2>/dev/null | head -2
    
    if [ $attempt -lt $MAX_ATTEMPTS ]; then
        echo "⏳ Attente de ${WAIT_TIME}s avant le prochain test..."
        sleep $WAIT_TIME
    fi
done

if [ $attempt -eq $MAX_ATTEMPTS ]; then
    echo " Services toujours pas prêts après $((MAX_ATTEMPTS * WAIT_TIME / 60)) minutes"
    echo " Exécutez ./scripts/manual-service-setup.sh pour forcer la configuration"
fi
