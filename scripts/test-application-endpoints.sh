#!/bin/bash

# Script pour tester tous les endpoints de l'application
set -e

echo " TEST DES ENDPOINTS DE L'APPLICATION"
echo "======================================"
echo ""

LB_IP="34.8.29.157"
MONITORING_IP="34.77.227.135"

# Fonction pour tester un endpoint
test_endpoint() {
    local url=$1
    local name=$2
    local expected_status=${3:-200}
    
    echo " Test de $name ($url)..."
    
    response=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 10 --max-time 30 "$url" 2>/dev/null || echo "000")
    
    if [ "$response" = "$expected_status" ]; then
        echo " $name: OK (HTTP $response)"
        return 0
    elif [ "$response" = "000" ]; then
        echo " $name: Connexion impossible"
        return 1
    else
        echo " $name: HTTP $response (attendu: $expected_status)"
        return 1
    fi
}

echo " Test des services principaux..."
test_endpoint "http://$LB_IP" "Load Balancer Frontend"
test_endpoint "http://$LB_IP/wp-admin/install.php" "Backend WordPress" 302
test_endpoint "http://$MONITORING_IP:3000" "Grafana" 302
test_endpoint "http://$MONITORING_IP:9090" "Prometheus"

echo ""
echo " Test des endpoints de santé..."
test_endpoint "http://$MONITORING_IP:3000/api/health" "Grafana Health" 200
test_endpoint "http://$MONITORING_IP:9090/-/healthy" "Prometheus Health"

echo ""
echo " Vérification des métriques..."
if curl -s "http://$MONITORING_IP:9090/api/v1/query?query=up" | grep -q '"status":"success"'; then
    echo " Prometheus collecte des métriques"
else
    echo " Prometheus en cours de configuration des métriques"
fi

echo ""
echo " Résultats des tests terminés"
