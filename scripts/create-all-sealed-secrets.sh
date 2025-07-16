#!/bin/bash

# Make sure we're in the right directory
cd "$(dirname "$0")/.."

echo "Creating all sealed secrets for K3s homelab..."

# Set MinIO credentials from environment or use defaults for development
MINIO_ACCESS_KEY=${MINIO_ACCESS_KEY:-"minioadmin"}
MINIO_SECRET_KEY=${MINIO_SECRET_KEY:-"minioadmin123"}
GITHUB_USERNAME=${GITHUB_USERNAME:-"jtayl222"}
GITHUB_PAT=${GITHUB_PAT:-"ghp_..."}
GITHUB_EMAIL=${GITHUB_EMAIL:-"your-email@example.com"}
MLFLOW_TRACKING_USERNAME=${MLFLOW_TRACKING_USERNAME:-"mlflow"}
MLFLOW_TRACKING_PASSWORD=${MLFLOW_TRACKING_PASSWORD:-"my-secure-mlflow-tracking-password"}
MLFLOW_DB_USERNAME=${MLFLOW_DB_USERNAME:-"mlflow"}
MLFLOW_DB_PASSWORD=${MLFLOW_DB_PASSWORD:-"mlflow-secure-password-123"}
#MLFLOW_FLASK_SECRET_KEY=${MLFLOW_FLASK_SECRET_KEY:-"$(openssl rand -base64 32)"}
MLFLOW_FLASK_SECRET_KEY=${MLFLOW_FLASK_SECRET_KEY:-"6EF6B30F9E557F948C402C89002C7C8A"}

##########################
# For the minio namespace
##########################

# Create MinIO secret for MinIO namespace
./scripts/create-sealed-secret.sh minio-credentials minio \
  access-key="$MINIO_ACCESS_KEY" \
  secret-key="$MINIO_SECRET_KEY"

##########################
# For the argowf namespace
##########################

./scripts/generate-ml-secrets.sh argowf argowf-team@company.com

##########################
# For the argocd namespace
##########################

./scripts/create-sealed-secret.sh minio-secret-cd argocd \
  AWS_ACCESS_KEY_ID="$MINIO_ACCESS_KEY" \
  AWS_SECRET_ACCESS_KEY="$MINIO_SECRET_KEY" \
  AWS_ENDPOINT_URL=http://minio.minio.svc.cluster.local:9000 \
  AWS_DEFAULT_REGION=us-east-1

# Create ArgoCD admin password secret
./scripts/create-sealed-secret.sh argocd-admin-secret argocd \
  admin-password=admin123

##########################
# For the jupyterhub namespace
##########################
./scripts/generate-ml-secrets.sh jupyterhub jupyterhub-team@company.com
./scripts/create-sealed-secret.sh jupyterhub-admin jupyterhub password=mlops123

##########################
# For the monitoring namespace
##########################

# Create Grafana secret for monitoring namespace
./scripts/create-sealed-secret.sh grafana-admin-secret monitoring \
  admin-password=admin123

##########################
# For the kserve namespace
##########################

# Create MinIO secret for KServe namespace
./scripts/create-sealed-secret.sh kserve-minio-secret kserve \
  AWS_ACCESS_KEY_ID="$MINIO_ACCESS_KEY" \
  AWS_SECRET_ACCESS_KEY="$MINIO_SECRET_KEY" \
  AWS_ENDPOINT_URL=http://minio.minio.svc.cluster.local:9000 \
  AWS_DEFAULT_REGION=us-east-1

##########################
# For the mlflow namespace
##########################

./scripts/create-sealed-secret.sh mlflow-s3-secret mlflow \
  AWS_ACCESS_KEY_ID="$MINIO_ACCESS_KEY" \
  AWS_SECRET_ACCESS_KEY="$MINIO_SECRET_KEY" \
  MLFLOW_S3_ENDPOINT_URL=http://minio.minio.svc.cluster.local:9000 \
  AWS_DEFAULT_REGION=us-east-1

./scripts/create-sealed-secret.sh mlflow-basic-auth mlflow \
  MLFLOW_TRACKING_USERNAME="$MLFLOW_TRACKING_USERNAME" \
  MLFLOW_TRACKING_PASSWORD="$MLFLOW_TRACKING_PASSWORD" \
  MLFLOW_FLASK_SERVER_SECRET_KEY="$MLFLOW_FLASK_SECRET_KEY"

./scripts/create-sealed-secret.sh mlflow-db-credentials mlflow \
  username="$MLFLOW_DB_USERNAME" \
  password="$MLFLOW_DB_PASSWORD" \
  MLFLOW_FLASK_SERVER_SECRET_KEY="$MLFLOW_FLASK_SECRET_KEY"

##########################
# For the iris-demo project
##########################

./scripts/generate-ml-secrets.sh iris-demo iris-demo-team@company.com


##########################
# For the harbor namespace
##########################

# Harbor Configuration
HARBOR_ADMIN_PASSWORD=${HARBOR_ADMIN_PASSWORD:-"Harbor12345"}
HARBOR_DATABASE_PASSWORD=${HARBOR_DATABASE_PASSWORD:-"changeit"}
HARBOR_SECRET_KEY=${HARBOR_SECRET_KEY:-"not-a-secure-key"}
HARBOR_REGISTRY_URL=${HARBOR_REGISTRY_URL:-"192.168.1.210"}

# Create Harbor admin secret
./scripts/create-sealed-secret.sh harbor-admin-secret harbor \
  admin-password="$HARBOR_ADMIN_PASSWORD" \
  database-password="$HARBOR_DATABASE_PASSWORD" \
  secret-key="$HARBOR_SECRET_KEY"

# Create Harbor registry secret for integration
./scripts/create-sealed-secret.sh harbor-registry-credentials harbor \
  registry-url="$HARBOR_REGISTRY_URL" \
  registry-username=admin \
  registry-password="$HARBOR_ADMIN_PASSWORD"

##########################
# For the jupyterhub project
##########################

echo "✅ All sealed secrets created successfully!"
echo ""
echo "🔑 To use custom credentials, set environment variables:"
echo "   export MINIO_ACCESS_KEY='your-access-key'"
echo "   export MINIO_SECRET_KEY='your-secret-key'"
echo "   export GITHUB_USERNAME='your-username'"
echo "   export GITHUB_PAT='your-personal-access-token'"
echo "   export GITHUB_EMAIL='your-email@example.com'"
echo "   export HARBOR_ADMIN_PASSWORD='your-harbor-password'"
echo "   export HARBOR_REGISTRY_URL='your-harbor-url'"
