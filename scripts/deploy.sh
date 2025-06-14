#!/bin/bash

# Deployment script for GCP infrastructure

set -e

ENVIRONMENT=${1:-preprod}
ACTION=${2:-plan}

echo " GCP Deployment Script"
echo "Environment: $ENVIRONMENT"
echo "Action: $ACTION"

# Validate environment
if [[ ! "$ENVIRONMENT" =~ ^(preprod|prod)$ ]]; then
    echo " Invalid environment. Use 'preprod' or 'prod'"
    exit 1
fi

# Validate action
if [[ ! "$ACTION" =~ ^(plan|apply|destroy)$ ]]; then
    echo " Invalid action. Use 'plan', 'apply', or 'destroy'"
    exit 1
fi

# Check if required tools are installed
command -v gcloud >/dev/null 2>&1 || { echo " gcloud CLI is required but not installed. Aborting." >&2; exit 1; }
command -v terraform >/dev/null 2>&1 || { echo " Terraform is required but not installed. Aborting." >&2; exit 1; }

# Set variables
PROJECT_ID="primordial-port-462408-q7"
REGION="europe-west1"
ZONE="europe-west1-b"

echo " Configuration:"
echo "  Project ID: $PROJECT_ID"
echo "  Region: $REGION"
echo "  Zone: $ZONE"
echo "  Environment: $ENVIRONMENT"

# Authenticate with GCP
echo " Authenticating with GCP..."
if [[ ! -f "terraform/service-account-key.json" ]]; then
    echo " Service account key file not found at terraform/service-account-key.json"
    exit 1
fi

gcloud auth activate-service-account --key-file=terraform/service-account-key.json
gcloud config set project $PROJECT_ID

# Create Terraform state bucket if it doesn't exist
echo " Ensuring Terraform state bucket exists..."
BUCKET_NAME="${PROJECT_ID}-terraform-state"
gsutil mb -p $PROJECT_ID -c STANDARD -l $REGION gs://$BUCKET_NAME/ 2>/dev/null || echo "Bucket already exists"
gsutil versioning set on gs://$BUCKET_NAME/

# Navigate to environment directory
cd terraform/$ENVIRONMENT

# Initialize Terraform
echo " Initializing Terraform..."
terraform init

# Prompt for database password if not set
if [[ -z "$TF_VAR_db_password" ]]; then
    echo " Please enter database password:"
    read -s TF_VAR_db_password
    export TF_VAR_db_password
fi

# Execute Terraform action
case $ACTION in
    plan)
        echo " Planning Terraform changes..."
        terraform plan -out=tfplan
        ;;
    apply)
        echo " Applying Terraform changes..."
        if [[ -f "tfplan" ]]; then
            terraform apply tfplan
        else
            terraform apply -auto-approve
        fi
        
        # Show outputs
        echo " Deployment outputs:"
        terraform output
        ;;
    destroy)
        echo " Destroying infrastructure..."
        echo "  This will destroy all resources in $ENVIRONMENT environment!"
        read -p "Are you sure? (yes/no): " confirm
        if [[ $confirm == "yes" ]]; then
            terraform destroy -auto-approve
        else
            echo "Destruction cancelled."
            exit 0
        fi
        ;;
esac

echo " Terraform $ACTION completed successfully!"

# If apply was successful, show next steps
if [[ $ACTION == "apply" ]]; then
    echo ""
    echo " Next steps:"
    echo "1. Configure DNS to point to the load balancer IP"
    echo "2. Wait for SSL certificate provisioning (if domain configured)"
    echo "3. Run Ansible configuration:"
    echo "   cd ../ansible && ansible-playbook -i inventory/gcp-$ENVIRONMENT.yml gcp-playbook.yml"
    echo "4. Access monitoring at: http://$(terraform output -raw monitoring_instance_ip):3000"
fi
