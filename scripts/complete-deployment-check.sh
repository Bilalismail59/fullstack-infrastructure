#!/bin/bash

# Script complet pour vérifier tout le déploiement
set -e

echo " VÉRIFICATION COMPLÈTE DU DÉPLOIEMENT"
echo "======================================="
echo ""

# Exécuter tous les scripts de vérification
echo " Vérification de l'état du déploiement..."
./scripts/check-deployment-status.sh

echo ""
echo " Test des endpoints de l'application..."
./scripts/test-application-endpoints.sh

echo ""
echo " Vérification des logs récents..."
./scripts/show-logs.sh

echo ""
echo " VÉRIFICATION COMPLÈTE TERMINÉE"
echo ""
echo " Actions recommandées:"
echo "• Attendez 5-10 minutes si certains services ne répondent pas encore"
echo "• Vérifiez les logs pour identifier d'éventuels problèmes"
echo "• Testez manuellement les URLs fournies"
echo "• Configurez les alertes de monitoring"
