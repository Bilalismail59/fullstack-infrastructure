#  Configuration pour Windows

##  Installation manuelle requise

### 1. Google Cloud CLI
1. Téléchargez depuis: https://cloud.google.com/sdk/docs/install-sdk#windows
2. Exécutez l'installateur
3. Redémarrez votre terminal

### 2. Terraform (optionnel)
1. Téléchargez depuis: https://www.terraform.io/downloads
2. Ajoutez à votre PATH

### 3. Git Bash
Assurez-vous d'utiliser Git Bash (pas PowerShell ou CMD)

##  Après installation

\`\`\`bash
# Exécutez ce script pour configurer l'environnement
./scripts/setup-local-environment.sh
\`\`\`

##  Alternative: Utiliser GitHub Actions

Si l'installation locale pose problème, utilisez GitHub Actions:

1. Commit et push vos changements
2. Allez sur GitHub → Actions
3. Run workflow → sélectionnez "unlock" puis "prod"
