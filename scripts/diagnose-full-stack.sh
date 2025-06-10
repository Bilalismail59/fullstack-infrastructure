#!/bin/bash

# Script de diagnostic complet de la stack
set -e

PROJECT_ID="primordial-port-462408-q7"
LB_IP="34.8.29.157"
MONITORING_IP="34.77.227.135"

echo " DIAGNOSTIC COMPLET DE LA STACK FULLSTACK"
echo "============================================="
echo ""

# 1. Vérifier l'état des instances
echo " 1. ÉTAT DES INSTANCES"
echo "------------------------"
gcloud compute instances list --project=$PROJECT_ID --format="table(name,zone,status,externalIP,internalIP)"
echo ""

# 2. Vérifier l'état des Instance Groups
echo " 2. ÉTAT DES INSTANCE GROUPS"
echo "------------------------------"
gcloud compute instance-groups managed list --project=$PROJECT_ID --format="table(name,location,targetSize,currentActions.creating,currentActions.deleting)"
echo ""

# 3. Vérifier l'état de santé du Load Balancer
echo " 3. SANTÉ DU LOAD BALANCER"
echo "----------------------------"
echo "Frontend Backend Service:"
gcloud compute backend-services get-health fullstack-app-frontend-backend --global --project=$PROJECT_ID 2>/dev/null || echo "❌ Erreur lors de la récupération de l'état frontend"
echo ""
echo "Backend Backend Service:"
gcloud compute backend-services get-health fullstack-app-backend-backend --global --project=$PROJECT_ID 2>/dev/null || echo "❌ Erreur lors de la récupération de l'état backend"
echo ""

# 4. Tester la connectivité
echo " 4. TESTS DE CONNECTIVITÉ"
echo "---------------------------"
echo "Test Load Balancer (Frontend):"
if curl -s --connect-timeout 10 -I http://$LB_IP | head -n 1; then
    echo " Load Balancer répond"
else
    echo " Load Balancer ne répond pas"
fi
echo ""

echo "Test Monitoring (Grafana):"
if curl -s --connect-timeout 10 -I http://$MONITORING_IP:3000 | head -n 1; then
    echo " Grafana accessible"
else
    echo " Grafana non accessible"
fi
echo ""

echo "Test Monitoring (Prometheus):"
if curl -s --connect-timeout 10 -I http://$MONITORING_IP:9090 | head -n 1; then
    echo " Prometheus accessible"
else
    echo " Prometheus non accessible"
fi
echo ""

# 5. Vérifier les logs des instances
echo " 5. LOGS DES INSTANCES (dernières 20 lignes)"
echo "----------------------------------------------"
INSTANCES=$(gcloud compute instances list --project=$PROJECT_ID --format="value(name,zone)")
echo "$INSTANCES" | while read -r NAME ZONE; do
    if [ -n "$NAME" ] && [ -n "$ZONE" ]; then
        echo " Logs pour $NAME:"
        gcloud compute instances get-serial-port-output $NAME --zone $ZONE --project $PROJECT_ID --quiet 2>/dev/null | tail -n 20 || echo "❌ Impossible de récupérer les logs pour $NAME"
        echo "----------------------------------------"
    fi
done

# 6. Vérifier la base de données
echo " 6. ÉTAT DE LA BASE DE DONNÉES"
echo "--------------------------------"
gcloud sql instances list --project=$PROJECT_ID --format="table(name,region,databaseVersion,state,ipAddresses[0].ipAddress)"
echo ""

# 7. Vérifier les règles de firewall
echo " 7. RÈGLES DE FIREWALL"
echo "-----------------------"
gcloud compute firewall-rules list --project=$PROJECT_ID --format="table(name,allowed[].map().firewall_rule().list():label=ALLOW,sourceRanges.list():label=SRC_RANGES,targetTags.list():label=TARGET_TAGS)"
echo ""

echo " Diagnostic terminé!"
