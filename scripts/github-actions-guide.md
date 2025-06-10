# Guide pour utiliser GitHub Actions

Si vous rencontrez des problèmes avec l'exécution locale de Terraform, vous pouvez utiliser GitHub Actions pour déployer votre infrastructure.

## Étapes à suivre

1. **Commit et push vos modifications**

\`\`\`bash
git add .
git commit -m "Update infrastructure scripts"
git push origin main
\`\`\`

2. **Accéder à GitHub Actions**

- Allez sur votre dépôt GitHub
- Cliquez sur l'onglet "Actions"
- Cliquez sur "Fullstack Infrastructure CI/CD" dans la liste des workflows

3. **Exécuter le workflow manuellement**

- Cliquez sur "Run workflow"
- Sélectionnez "unlock" dans le menu déroulant
- Cliquez sur "Run workflow"
- Attendez que le workflow se termine

4. **Déployer l'infrastructure**

- Cliquez à nouveau sur "Run workflow"
- Sélectionnez "prod" ou "preprod" dans le menu déroulant
- Cliquez sur "Run workflow"
- Attendez que le déploiement se termine

## Avantages de GitHub Actions

- Environnement d'exécution cohérent
- Pas de problèmes de permissions locales
- Authentification gérée par les secrets GitHub
- Logs détaillés pour le débogage
