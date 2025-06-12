#!/bin/bash

# Script pour configurer manuellement les services si les scripts de démarrage ont échoué
set -e

echo " CONFIGURATION MANUELLE DES SERVICES"
echo "======================================"
echo ""

PROJECT_ID="primordial-port-462408-q7"

# Configuration manuelle pour les instances frontend
setup_frontend() {
    local name=$1
    local zone=$2

    echo " Configuration manuelle du frontend: $name"

    gcloud compute ssh "$name" --zone="$zone" --project="$PROJECT_ID" --command='
        echo "=== Installation et configuration Frontend ==="

        # Mise à jour du système
        sudo apt update

        # Installation de Nginx
        if ! command -v nginx &> /dev/null; then
            echo "Installation de Nginx..."
            sudo apt install -y nginx
        fi

        # Installation de Node.js
        if ! command -v node &> /dev/null; then
            echo "Installation de Node.js..."
            curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
            sudo apt install -y nodejs
        fi

        # Configuration Nginx
        sudo bash -c "cat > /etc/nginx/sites-available/default" <<EOF
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    root /var/www/html;
    index index.html index.htm index.nginx-debian.html;

    server_name _;

    location / {
        try_files \$uri \$uri/ =404;
    }

    location /health {
        access_log off;
        return 200 "healthy";
        add_header Content-Type text/plain;
    }
}
EOF

        # Page d accueil simple
        sudo bash -c "cat > /var/www/html/index.html" <<EOF
<!DOCTYPE html>
<html>
<head><title>Frontend Instance</title></head>
<body>
    <h1>Frontend Instance Active</h1>
    <p>Hostname: \$(hostname)</p>
    <p>Date: \$(date)</p>
</body>
</html>
EOF

        sudo systemctl enable nginx
        sudo systemctl restart nginx

        echo "Statut des services:"
        sudo systemctl status nginx --no-pager -l
        echo "Test local:"
        curl -s http://localhost/ | head -5 || echo "Test local échoué"
    ' --quiet || echo " Erreur lors de la configuration de $name"
}

# Configuration manuelle pour les instances backend
setup_backend() {
    local name=$1
    local zone=$2

    echo " Configuration manuelle du backend: $name"

    gcloud compute ssh "$name" --zone="$zone" --project="$PROJECT_ID" --command='
        echo "=== Installation et configuration Backend ==="

        sudo apt update

        if ! command -v apache2 &> /dev/null; then
            echo "Installation d Apache et PHP..."
            sudo apt install -y apache2 php php-mysql php-gd php-xml php-mbstring php-curl
        fi

        sudo bash -c "cat > /var/www/html/index.php" <<EOF
<?php
echo "<h1>Backend Instance Active</h1>";
echo "<p>Hostname: " . gethostname() . "</p>";
echo "<p>Date: " . date("Y-m-d H:i:s") . "</p>";
echo "<p>PHP Version: " . phpversion() . "</p>";
?>
EOF

        sudo a2enmod rewrite
        sudo systemctl enable apache2
        sudo systemctl restart apache2

        echo "Statut des services:"
        sudo systemctl status apache2 --no-pager -l
        echo "Test local:"
        curl -s http://localhost/ | head -5 || echo "Test local échoué"
    ' --quiet || echo " Erreur lors de la configuration de $name"
}

echo " Configuration manuelle de toutes les instances..."
gcloud compute instances list --project="$PROJECT_ID" --format="value(name,zone)" | while read -r NAME ZONE_FULL; do
    ZONE=$(basename "$ZONE_FULL")  # extrait uniquement la zone à partir de l'URL
    if [[ "$NAME" == *frontend* ]]; then
        setup_frontend "$NAME" "$ZONE"
    elif [[ "$NAME" == *backend* ]]; then
        setup_backend "$NAME" "$ZONE"
    fi
    echo "----------------------------------------"
done

echo " Configuration manuelle terminée."
echo " Attendez 2-3 minutes puis testez à nouveau les endpoints."
