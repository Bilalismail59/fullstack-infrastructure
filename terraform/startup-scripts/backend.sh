#!/bin/bash

# Update system
apt-get update
apt-get upgrade -y

# Install required packages
apt-get install -y apache2 mysql-client php php-mysql php-gd php-xml php-mbstring php-curl wget unzip

# Start and enable Apache
systemctl start apache2
systemctl enable apache2

# Download and setup WordPress
cd /tmp
wget https://wordpress.org/latest.tar.gz
tar xzf latest.tar.gz
cp -R wordpress/* /var/www/html/
rm -f /var/www/html/index.html

# Set permissions
chown -R www-data:www-data /var/www/html/
chmod -R 755 /var/www/html/

# Configure WordPress
cp /var/www/html/wp-config-sample.php /var/www/html/wp-config.php

# Replace database configuration
sed -i "s/database_name_here/wordpress/" /var/www/html/wp-config.php
sed -i "s/username_here/wordpress/" /var/www/html/wp-config.php
sed -i "s/password_here/${db_password}/" /var/www/html/wp-config.php
sed -i "s/localhost/${db_host}/" /var/www/html/wp-config.php

# Configure Apache
cat > /etc/apache2/sites-available/000-default.conf << 'EOF'
<VirtualHost *:80>
    ServerAdmin webmaster@localhost
    DocumentRoot /var/www/html

    <Directory /var/www/html>
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog /var/log/apache2/error.log
    CustomLog /var/log/apache2/access.log combined
</VirtualHost>
EOF

# Enable mod_rewrite
a2enmod rewrite
systemctl restart apache2

# Configure firewall
ufw allow 22
ufw allow 80
ufw allow 443
ufw --force enable

# Install monitoring agent
wget https://github.com/prometheus/node_exporter/releases/download/v1.6.1/node_exporter-1.6.1.linux-amd64.tar.gz
tar xvfz node_exporter-1.6.1.linux-amd64.tar.gz
cp node_exporter-1.6.1.linux-amd64/node_exporter /usr/local/bin/
useradd --no-create-home --shell /bin/false node_exporter
chown node_exporter:node_exporter /usr/local/bin/node_exporter

# Create systemd service for node_exporter
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

# Install Google Cloud Ops Agent
curl -sSO https://dl.google.com/cloudagents/add-google-cloud-ops-agent-repo.sh
bash add-google-cloud-ops-agent-repo.sh --also-install

# Log completion
echo "Backend setup completed at $(date)" >> /var/log/startup-script.log
