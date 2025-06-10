#!/bin/bash

# Script de test complet de la stack
set -e

LB_IP="34.8.29.157"
MONITORING_IP="34.77.227.135"

echo " TEST COMPLET DE LA STACK FULLSTACK"
echo "====================================="

# 1. Test du frontend
echo " 1. TEST DU FRONTEND"
echo "---------------------"
echo "URL: http://$LB_IP"
if curl -s -o /dev/null -w "%{http_code}" http://$LB_IP | grep -q "200"; then
    echo " Frontend accessible"
    curl -s http://$LB_IP | head -n 10
else
    echo " Frontend non accessible"
fi
echo ""

# 2. Test du backend/API
echo " 2. TEST DU BACKEND/API"
echo "------------------------"
echo "URL: http://$LB_IP/api/wp-json/wp/v2/posts"
if curl -s -o /dev/null -w "%{http_code}" http://$LB_IP/api/wp-json/wp/v2/posts | grep -q "200"; then
    echo " Backend API accessible"
    curl -s http://$LB_IP/api/wp-json/wp/v2/posts | jq '.[0].title.rendered' 2>/dev/null || echo "Posts récupérés"
else
    echo " Backend API non accessible"
fi
echo ""

# 3. Test de monitoring
echo " 3. TEST DU MONITORING"
echo "-----------------------"
echo "Grafana: http://$MONITORING_IP:3000"
if curl -s -o /dev/null -w "%{http_code}" http://$MONITORING_IP:3000 | grep -q "200"; then
    echo " Grafana accessible"
else
    echo " Grafana non accessible"
fi

echo "Prometheus: http://$MONITORING_IP:9090"
if curl -s -o /dev/null -w "%{http_code}" http://$MONITORING_IP:9090 | grep -q "200"; then
    echo " Prometheus accessible"
else
    echo " Prometheus non accessible"
fi
echo ""

# 4. Test des métriques
echo " 4. TEST DES MÉTRIQUES"
echo "-----------------------"
if curl -s http://$MONITORING_IP:9090/api/v1/query?query=up | jq '.data.result | length' >/dev/null 2>&1; then
    TARGETS=$(curl -s http://$MONITORING_IP:9090/api/v1/query?query=up | jq '.data.result | length')
    echo " Prometheus collecte des métriques ($TARGETS targets)"
else
    echo " Problème avec la collecte de métriques"
fi
echo ""

# 5. Résumé
echo " 5. RÉSUMÉ"
echo "-----------"
echo " URLs d'accès:"
echo "  - Application: http://$LB_IP"
echo "  - API: http://$LB_IP/api/wp-json/wp/v2/posts"
echo "  - Grafana: http://$MONITORING_IP:3000 (admin/admin123)"
echo "  - Prometheus: http://$MONITORING_IP:9090"
echo ""
echo " Test complet terminé!"
