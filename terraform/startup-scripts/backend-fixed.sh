#!/bin/bash

# Script de démarrage backend corrigé et optimisé
set -e

# Logging
exec > >(tee /var/log/startup-script.log)
exec 2>&1

echo "🚀 Démarrage du script backend - $(date)"

# Variables d'environnement
DB_HOST="10.0.2.2"  # IP privée de Cloud SQL
DB_PASSWORD="SecurePassword123!"

# Mise à jour du système
echo "📦 Mise à jour du système..."
apt-get update
apt-get upgrade -y

# Installation des dépendances
echo "🔧 Installation des dépendances..."
apt-get install -y apache2 mysql-client php php-mysql php-gd php-xml php-mbstring php-curl php-zip php-intl wget unzip ufw fail2ban

# Configuration du firewall
echo "🔥 Configuration du firewall..."
ufw allow 22
ufw allow 80
ufw allow 443
ufw allow 9100  # Node exporter
ufw --force enable

# Téléchargement et installation de WordPress
echo "📥 Téléchargement de WordPress..."
cd /tmp
wget https://wordpress.org/latest.tar.gz
tar xzf latest.tar.gz
rm -rf /var/www/html/*
cp -R wordpress/* /var/www/html/
rm -f /var/www/html/index.html

# Configuration des permissions
echo "🔒 Configuration des permissions..."
chown -R www-data:www-data /var/www/html/
chmod -R 755 /var/www/html/

# Configuration de WordPress
echo "⚙️ Configuration de WordPress..."
cp /var/www/html/wp-config-sample.php /var/www/html/wp-config.php

# Configuration de la base de données
sed -i "s/database_name_here/wordpress/" /var/www/html/wp-config.php
sed -i "s/username_here/wordpress/" /var/www/html/wp-config.php
sed -i "s/password_here/$DB_PASSWORD/" /var/www/html/wp-config.php
sed -i "s/localhost/$DB_HOST/" /var/www/html/wp-config.php

# Ajout des clés de sécurité WordPress
echo "🔐 Configuration des clés de sécurité..."
SALT=$(curl -L https://api.wordpress.org/secret-key/1.1/salt/)
STRING='put your unique phrase here'
printf '%s\n' "g?$STRING?d" | sed -i -f- /var/www/html/wp-config.php
printf '%s\n' "g?$STRING?r $SALT" | sed -i -f- /var/www/html/wp-config.php

# Configuration d'Apache
echo "🌐 Configuration d'Apache..."
cat > /etc/apache2/sites-available/000-default.conf << 'EOF'
<VirtualHost *:80>
    ServerAdmin webmaster@localhost
    DocumentRoot /var/www/html

    <Directory /var/www/html>
        AllowOverride All
        Require all granted
    </Directory>

    # Health check endpoint
    Alias /health /var/www/health
    <Location /health>
        SetHandler server-status
    </Location>

    # API endpoint for frontend
    Alias /api /var/www/html/wp-json

    ErrorLog ${APACHE_LOG_DIR}/error.log
    CustomLog ${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOF

# Créer un endpoint de santé simple
mkdir -p /var/www
echo "healthy" > /var/www/health

# Activer mod_rewrite et mod_headers
a2enmod rewrite
a2enmod headers

# Démarrer Apache
systemctl start apache2
systemctl enable apache2
systemctl restart apache2

# Créer un script de test de connexion DB
echo "🗄️ Test de connexion à la base de données..."
cat > /tmp/test_db.php << EOF
<?php
\$host = '$DB_HOST';
\$username = 'wordpress';
\$password = '$DB_PASSWORD';
\$database = 'wordpress';

try {
    \$pdo = new PDO("mysql:host=\$host;dbname=\$database", \$username, \$password);
    \$pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    echo "✅ Database connection successful\n";
    
    // Test query
    \$stmt = \$pdo->query('SELECT VERSION()');
    \$version = \$stmt->fetchColumn();
    echo "📊 MySQL version: \$version\n";
    
} catch(PDOException \$e) {
    echo "❌ Database connection failed: " . \$e->getMessage() . "\n";
}
?>
EOF

php /tmp/test_db.php

# Installation de WP-CLI
echo "🔧 Installation de WP-CLI..."
curl -O https://raw.githubusercontent.com/wp-cli/wp-cli/v2.8.1/wp-cli.phar
chmod +x wp-cli.phar
mv wp-cli.phar /usr/local/bin/wp

# Configuration initiale de WordPress via WP-CLI
echo "⚙️ Configuration initiale de WordPress..."
cd /var/www/html
sudo -u www-data wp core install \
    --url="http://$(curl -s http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip -H "Metadata-Flavor: Google")" \
    --title="Fullstack Application" \
    --admin_user="admin" \
    --admin_password="admin123" \
    --admin_email="admin@example.com" \
    --skip-email

# Activer l'API REST
sudo -u www-data wp rewrite structure '/%postname%/'
sudo -u www-data wp rewrite flush

# Créer quelques posts de test
sudo -u www-data wp post create --post_title="Welcome to Fullstack App" --post_content="This is a test post from the backend." --post_status=publish
sudo -u www-data wp post create --post_title="API Test" --post_content="This post is accessible via REST API." --post_status=publish

# Installation de Node Exporter pour monitoring
echo "📊 Installation de Node Exporter..."
wget https://github.com/prometheus/node_exporter/releases/download/v1.6.1/node_exporter-1.6.1.linux-amd64.tar.gz
tar xvfz node_exporter-1.6.1.linux-amd64.tar.gz
cp node_exporter-1.6.1.linux-amd64/node_exporter /usr/local/bin/
useradd --no-create-home --shell /bin/false node_exporter
chown node_exporter:node_exporter /usr/local/bin/node_exporter

# Service systemd pour node_exporter
cat > /etc/systemd/system/node_exporter.service << 'EOF'
[Unit]
Description=Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl start node_exporter
systemctl enable node_exporter

# Installation de Google Cloud Ops Agent
echo "☁️ Installation de Google Cloud Ops Agent..."
curl -sSO https://dl.google.com/cloudagents/add-google-cloud-ops-agent-repo.sh
bash add-google-cloud-ops-agent-repo.sh --also-install

echo "✅ Backend setup completed at $(date)"
echo "🌐 WordPress should be available on port 80"
echo "📊 Node Exporter available on port 9100"
echo "🔑 WordPress admin: admin/admin123"
