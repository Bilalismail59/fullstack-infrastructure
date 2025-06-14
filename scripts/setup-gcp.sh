#!/bin/bash

# Setup script for GCP infrastructure deployment

set -e

echo " Setting up GCP Full Stack Infrastructure"

# Check if required tools are installed
command -v gcloud >/dev/null 2>&1 || { echo " gcloud CLI is required but not installed. Aborting." >&2; exit 1; }
command -v terraform >/dev/null 2>&1 || { echo " Terraform is required but not installed. Aborting." >&2; exit 1; }
command -v ansible >/dev/null 2>&1 || { echo " Ansible is required but not installed. Aborting." >&2; exit 1; }

# Set variables
PROJECT_ID="primordial-port-462408-q7"
REGION="europe-west1"
ZONE="europe-west1-b"
ENVIRONMENT=${1:-preprod}

echo " Configuration:"
echo "  Project ID: $PROJECT_ID"
echo "  Region: $REGION"
echo "  Zone: $ZONE"
echo "  Environment: $ENVIRONMENT"

# Authenticate with GCP
echo " Authenticating with GCP..."
gcloud auth activate-service-account --key-file=terraform/service-account-key.json
gcloud config set project $PROJECT_ID

# Enable required APIs
echo " Enabling required GCP APIs..."
gcloud services enable compute.googleapis.com
gcloud services enable container.googleapis.com
gcloud services enable sqladmin.googleapis.com
gcloud services enable monitoring.googleapis.com
gcloud services enable logging.googleapis.com

# Create Terraform state bucket
echo " Creating Terraform state bucket..."
BUCKET_NAME="${PROJECT_ID}-terraform-state"
gsutil mb -p $PROJECT_ID -c STANDARD -l $REGION gs://$BUCKET_NAME/ 2>/dev/null || echo "Bucket already exists"
gsutil versioning set on gs://$BUCKET_NAME/

# Initialize and apply Terraform
echo " Deploying infrastructure with Terraform..."
cd terraform

# Create backend configuration
cat > backend.tf << EOF
terraform {
  backend "gcs" {
    bucket = "$BUCKET_NAME"
    prefix = "$ENVIRONMENT/terraform/state"
  }
}
EOF

# Initialize Terraform
terraform init

# Plan and apply
terraform plan \
  -var="environment=$ENVIRONMENT" \
  -var="project_id=$PROJECT_ID" \
  -var="region=$REGION" \
  -var="zone=$ZONE" \
  -var="db_password=SecurePassword123!" \
  -out=tfplan

terraform apply -auto-approve tfplan

# Get instance IPs for Ansible
echo " Getting instance IPs..."
FRONTEND_IP=$(gcloud compute instances list --filter="name~frontend" --format="value(EXTERNAL_IP)" --limit=1)
BACKEND_IP=$(gcloud compute instances list --filter="name~backend" --format="value(EXTERNAL_IP)" --limit=1)
MONITORING_IP=$(gcloud compute instances list --filter="name~monitoring" --format="value(EXTERNAL_IP)" --limit=1)

cd ../ansible

# Create dynamic inventory
cat > inventory/gcp-${ENVIRONMENT}.yml << EOF
all:
  children:
    frontend:
      hosts:
        ${ENVIRONMENT}-frontend:
          ansible_host: $FRONTEND_IP
          ansible_user: ubuntu
          ansible_ssh_private_key_file: ~/.ssh/gcp-key
    backend:
      hosts:
        ${ENVIRONMENT}-backend:
          ansible_host: $BACKEND_IP
          ansible_user: ubuntu
          ansible_ssh_private_key_file: ~/.ssh/gcp-key
    monitoring:
      hosts:
        ${ENVIRONMENT}-monitoring:
          ansible_host: $MONITORING_IP
          ansible_user: ubuntu
          ansible_ssh_private_key_file: ~/.ssh/gcp-key
  vars:
    env: $ENVIRONMENT
    gcp_project: $PROJECT_ID
    gcp_region: $REGION
EOF

# Wait for instances to be ready
echo " Waiting for instances to be ready..."
sleep 60

# Run Ansible playbook
echo " Configuring servers with Ansible..."
ansible-playbook -i inventory/gcp-${ENVIRONMENT}.yml gcp-playbook.yml

echo " Deployment completed successfully!"
echo ""
echo " Access URLs:"
echo "  Frontend: http://$FRONTEND_IP"
echo "  Backend: http://$BACKEND_IP"
echo "  Monitoring: http://$MONITORING_IP:3000 (Grafana)"
echo "  Prometheus: http://$MONITORING_IP:9090"
echo ""
echo " Default credentials:"
echo "  Grafana: admin/admin123"
echo ""
echo " Next steps:"
echo "  1. Configure your domain DNS to point to the load balancer IP"
echo "  2. Set up SSL certificates"
echo "  3. Configure monitoring alerts"
echo "  4. Set up backup policies"
