#  Fullstack Infrastructure GCP

Infrastructure complète avec Frontend React, Backend WordPress, Base de données MySQL et Monitoring.

##  Scripts essentiels

###  Installation et configuration
- `install-tools.sh` - Installe tous les outils nécessaires (gcloud, terraform, etc.)

###  Déploiement
- `complete-infrastructure.sh` - Déploie l'infrastructure complète (preprod + prod + Kubernetes)
- `diagnose-full-stack.sh` - Diagnostic complet de l'état de la stack
- `fix-frontend-backend.sh` - Corrige et redémarre frontend/backend
- `fix-load-balancer.sh` - Corrige la configuration du Load Balancer

###  Tests et monitoring
- `complete-stack-test.sh` - Test complet de tous les composants
- `test-database-connection.sh` - Test de connexion à la base de données
- `wait-and-test.sh` - Attendre que tout soit opérationnel et tester

###  Nettoyage
- `cleanup-gcp.sh` - Supprime toute l'infrastructure

##  Démarrage rapide

1. **Installation des outils** :
   \`\`\`bash
   ./scripts/install-tools.sh
   \`\`\`

2. **Déploiement complet** :
   \`\`\`bash
   ./scripts/complete-infrastructure.sh
   \`\`\`

3. **Test de la stack** :
   \`\`\`bash
   ./scripts/wait-and-test.sh
   \`\`\`

##  URLs d'accès

- **Application** : http://34.8.29.157
- **Grafana** : http://34.77.227.135:3000 (admin/admin123)
- **Prometheus** : http://34.77.227.135:9090

##  En cas de problème

1. **Diagnostic** :
   \`\`\`bash
   ./scripts/diagnose-full-stack.sh
   \`\`\`

2. **Correction** :
   \`\`\`bash
   ./scripts/fix-frontend-backend.sh
   ./scripts/fix-load-balancer.sh
   \`\`\`

3. **Test** :
   \`\`\`bash
   ./scripts/complete-stack-test.sh
