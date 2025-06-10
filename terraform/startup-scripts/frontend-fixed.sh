#!/bin/bash

# Script de démarrage frontend corrigé et optimisé
set -e

# Logging
exec > >(tee /var/log/startup-script.log)
exec 2>&1

echo " Démarrage du script frontend - $(date)"

# Mise à jour du système
echo " Mise à jour du système..."
apt-get update
apt-get upgrade -y

# Installation des dépendances de base
echo " Installation des dépendances..."
apt-get install -y curl wget git nginx ufw fail2ban htop vim unzip

# Installation de Node.js 18
echo " Installation de Node.js 18..."
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt-get install -y nodejs

# Vérification de l'installation
node --version
npm --version

# Configuration du firewall
echo " Configuration du firewall..."
ufw allow 22
ufw allow 80
ufw allow 443
ufw allow 9100  # Node exporter
ufw --force enable

# Création de l'utilisateur application
echo "👤 Création de l'utilisateur application..."
useradd -m -s /bin/bash appuser
usermod -aG sudo appuser

# Création d'une application Vite simple
echo " Création de l'application frontend..."
cd /home/appuser
mkdir -p app
cd app

# Créer un package.json simple
cat > package.json << 'EOF'
{
  "name": "fullstack-frontend",
  "private": true,
  "version": "0.0.0",
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "vite build",
    "preview": "vite preview --port 3000 --host"
  },
  "dependencies": {
    "react": "^18.2.0",
    "react-dom": "^18.2.0"
  },
  "devDependencies": {
    "@types/react": "^18.2.43",
    "@types/react-dom": "^18.2.17",
    "@vitejs/plugin-react": "^4.2.1",
    "vite": "^5.0.8"
  }
}
EOF

# Créer vite.config.js
cat > vite.config.js << 'EOF'
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  server: {
    port: 3000,
    host: '0.0.0.0'
  },
  preview: {
    port: 3000,
    host: '0.0.0.0'
  }
})
EOF

# Créer index.html
cat > index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Fullstack App</title>
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/main.jsx"></script>
  </body>
</html>
EOF

# Créer le dossier src
mkdir -p src

# Créer src/main.jsx
cat > src/main.jsx << 'EOF'
import React from 'react'
import ReactDOM from 'react-dom/client'
import App from './App.jsx'

ReactDOM.createRoot(document.getElementById('root')).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>,
)
EOF

# Créer src/App.jsx
cat > src/App.jsx << 'EOF'
import React, { useState, useEffect } from 'react'

function App() {
  const [backendStatus, setBackendStatus] = useState('Checking...')
  const [dbStatus, setDbStatus] = useState('Checking...')

  useEffect(() => {
    // Test backend connection
    fetch('/api/health')
      .then(res => res.ok ? 'Connected' : 'Error')
      .catch(() => 'Disconnected')
      .then(setBackendStatus)

    // Test database connection
    fetch('/api/db-status')
      .then(res => res.ok ? 'Connected' : 'Error')
      .catch(() => 'Disconnected')
      .then(setDbStatus)
  }, [])

  return (
    <div style={{ 
      fontFamily: 'Arial, sans-serif', 
      maxWidth: '800px', 
      margin: '0 auto', 
      padding: '20px',
      backgroundColor: '#f5f5f5',
      minHeight: '100vh'
    }}>
      <header style={{ 
        backgroundColor: '#2563eb', 
        color: 'white', 
        padding: '20px', 
        borderRadius: '8px',
        marginBottom: '20px'
      }}>
        <h1> Fullstack Application</h1>
        <p>Frontend React + Backend WordPress + Database MySQL</p>
      </header>

      <div style={{ 
        display: 'grid', 
        gridTemplateColumns: 'repeat(auto-fit, minmax(250px, 1fr))', 
        gap: '20px' 
      }}>
        <div style={{ 
          backgroundColor: 'white', 
          padding: '20px', 
          borderRadius: '8px',
          boxShadow: '0 2px 4px rgba(0,0,0,0.1)'
        }}>
          <h2> Frontend</h2>
          <p><strong>Status:</strong> <span style={{color: 'green'}}> Running</span></p>
          <p><strong>Framework:</strong> React + Vite</p>
          <p><strong>Port:</strong> 3000</p>
        </div>

        <div style={{ 
          backgroundColor: 'white', 
          padding: '20px', 
          borderRadius: '8px',
          boxShadow: '0 2px 4px rgba(0,0,0,0.1)'
        }}>
          <h2> Backend</h2>
          <p><strong>Status:</strong> <span style={{color: backendStatus === 'Connected' ? 'green' : 'red'}}>
            {backendStatus === 'Connected' ? '' : ''} {backendStatus}
          </span></p>
          <p><strong>Framework:</strong> WordPress</p>
          <p><strong>API:</strong> REST API</p>
        </div>

        <div style={{ 
          backgroundColor: 'white', 
          padding: '20px', 
          borderRadius: '8px',
          boxShadow: '0 2px 4px rgba(0,0,0,0.1)'
        }}>
          <h2> Database</h2>
          <p><strong>Status:</strong> <span style={{color: dbStatus === 'Connected' ? 'green' : 'red'}}>
            {dbStatus === 'Connected' ? '' : ''} {dbStatus}
          </span></p>
          <p><strong>Type:</strong> MySQL 8.0</p>
          <p><strong>Host:</strong> Cloud SQL</p>
        </div>
      </div>

      <div style={{ 
        backgroundColor: 'white', 
        padding: '20px', 
        borderRadius: '8px',
        boxShadow: '0 2px 4px rgba(0,0,0,0.1)',
        marginTop: '20px'
      }}>
        <h2> System Information</h2>
        <p><strong>Environment:</strong> Google Cloud Platform</p>
        <p><strong>Load Balancer:</strong> 34.8.29.157</p>
        <p><strong>Monitoring:</strong> 34.77.227.135:3000</p>
        <p><strong>Deployment:</strong> {new Date().toLocaleString()}</p>
      </div>
    </div>
  )
}

export default App
EOF

# Changer les permissions
chown -R appuser:appuser /home/appuser/app

# Installation des dépendances
echo " Installation des dépendances npm..."
cd /home/appuser/app
sudo -u appuser npm install

# Build de l'application
echo " Build de l'application..."
sudo -u appuser npm run build

# Installation de PM2
echo " Installation de PM2..."
npm install -g pm2

# Configuration de Nginx
echo " Configuration de Nginx..."
cat > /etc/nginx/sites-available/default << 'EOF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    root /home/appuser/app/dist;
    index index.html;

    server_name _;

    # Serve static files
    location / {
        try_files $uri $uri/ /index.html;
    }

    # Proxy API calls to backend
    location /api/ {
        proxy_pass http://backend-service/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }

    # Health check endpoint
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
}
EOF

# Démarrer et activer Nginx
systemctl start nginx
systemctl enable nginx
systemctl reload nginx

# Installation de Node Exporter pour monitoring
echo " Installation de Node Exporter..."
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
echo " Installation de Google Cloud Ops Agent..."
curl -sSO https://dl.google.com/cloudagents/add-google-cloud-ops-agent-repo.sh
bash add-google-cloud-ops-agent-repo.sh --also-install

echo " Frontend setup completed at $(date)"
echo " Application should be available on port 80"
echo " Node Exporter available on port 9100"
