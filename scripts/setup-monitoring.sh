#!/bin/bash

# Setup monitoring stack on GCP

set -e

ENVIRONMENT=${1:-preprod}

echo " Setting up monitoring for $ENVIRONMENT environment"

# Get monitoring instance IP
MONITORING_IP=$(gcloud compute instances list --filter="name~$ENVIRONMENT-monitoring" --format="value(EXTERNAL_IP)" --limit=1)

if [[ -z "$MONITORING_IP" ]]; then
    echo " Monitoring instance not found for environment: $ENVIRONMENT"
    exit 1
fi

echo "  Monitoring instance IP: $MONITORING_IP"

# Wait for instance to be ready
echo " Waiting for monitoring instance to be ready..."
sleep 60

# Check if services are running
echo " Checking monitoring services..."

# Check Grafana
if curl -s -o /dev/null -w "%{http_code}" http://$MONITORING_IP:3000 | grep -q "200\|302"; then
    echo " Grafana is running at http://$MONITORING_IP:3000"
    echo "   Default credentials: admin/admin123"
else
    echo "  Grafana is not yet available. It may still be starting up."
fi

# Check Prometheus
if curl -s -o /dev/null -w "%{http_code}" http://$MONITORING_IP:9090 | grep -q "200"; then
    echo " Prometheus is running at http://$MONITORING_IP:9090"
else
    echo "  Prometheus is not yet available. It may still be starting up."
fi

# Check Alertmanager
if curl -s -o /dev/null -w "%{http_code}" http://$MONITORING_IP:9093 | grep -q "200"; then
    echo " Alertmanager is running at http://$MONITORING_IP:9093"
else
    echo "  Alertmanager is not yet available. It may still be starting up."
fi

echo ""
echo " Monitoring URLs:"
echo "  Grafana:      http://$MONITORING_IP:3000"
echo "  Prometheus:   http://$MONITORING_IP:9090"
echo "  Alertmanager: http://$MONITORING_IP:9093"
echo ""
echo " Next steps:"
echo "1. Access Grafana and change default password"
echo "2. Import custom dashboards"
echo "3. Configure alert notification channels"
echo "4. Set up backup for monitoring data"
