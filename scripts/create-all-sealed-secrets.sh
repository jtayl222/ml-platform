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

echo "🔐 Creating MinIO credentials..."
# Create MinIO secret for MinIO namespace
./scripts/create-sealed-secret.sh minio-credentials minio \
  access-key="$MINIO_ACCESS_KEY" \
  secret-key="$MINIO_SECRET_KEY"

# MinIO secret for argowf namespace (workflows need access)
./scripts/create-sealed-secret.sh minio-credentials-wf argowf \
  access-key="$MINIO_ACCESS_KEY" \
  secret-key="$MINIO_SECRET_KEY" \
  AWS_ACCESS_KEY_ID="$MINIO_ACCESS_KEY" \
  AWS_SECRET_ACCESS_KEY="$MINIO_SECRET_KEY" \
  AWS_ENDPOINT_URL=http://minio.minio.svc.cluster.local:9000 \
  AWS_DEFAULT_REGION=us-east-1 \
  MLFLOW_S3_ENDPOINT_URL=http://minio.minio.svc.cluster.local:9000

echo "🔐 Creating application secrets..."
# Create MLflow S3 secret for mlflow namespace
./scripts/create-sealed-secret.sh mlflow-s3-secret mlflow \
  AWS_ACCESS_KEY_ID="$MINIO_ACCESS_KEY" \
  AWS_SECRET_ACCESS_KEY="$MINIO_SECRET_KEY" \
  MLFLOW_S3_ENDPOINT_URL=http://minio.minio.svc.cluster.local:9000 \
  AWS_DEFAULT_REGION=us-east-1

# Create MinIO secret for Argo CD (AWS S3 compatible format)
./scripts/create-sealed-secret.sh minio-secret-cd argocd \
  AWS_ACCESS_KEY_ID="$MINIO_ACCESS_KEY" \
  AWS_SECRET_ACCESS_KEY="$MINIO_SECRET_KEY" \
  AWS_ENDPOINT_URL=http://minio.minio.svc.cluster.local:9000 \
  AWS_DEFAULT_REGION=us-east-1

echo "🔐 Creating service account secrets..."
# Create JupyterHub admin password secret  
./scripts/create-sealed-secret.sh jupyterhub-admin jupyterhub \
  password=mlops123

# Create ArgoCD admin password secret
./scripts/create-sealed-secret.sh argocd-admin-secret argocd \
  admin-password=admin123

# Create Grafana secret for monitoring namespace
./scripts/create-sealed-secret.sh grafana-admin-secret monitoring \
  admin-password=admin123

# Create MinIO secret for KServe namespace
./scripts/create-sealed-secret.sh kserve-minio-secret kserve \
  AWS_ACCESS_KEY_ID="minioadmin" \
  AWS_SECRET_ACCESS_KEY="minioadmin123" \
  AWS_ENDPOINT_URL=http://minio.minio.svc.cluster.local:9000 \
  AWS_DEFAULT_REGION=us-east-1

echo "🔐 Creating container registry secrets..."
# GitHub Container Registry credentials
./scripts/create-sealed-docker-secret.sh ghcr-credentials argowf \
  ghcr.io \
  "$GITHUB_USERNAME" \
  "$GITHUB_PAT" \
  "$GITHUB_EMAIL"

echo "✅ All sealed secrets created successfully!"
echo ""
echo "🔑 To use custom credentials, set environment variables:"
echo "   export MINIO_ACCESS_KEY='your-access-key'"
echo "   export MINIO_SECRET_KEY='your-secret-key'"
echo "   export GITHUB_USERNAME='your-username'"
echo "   export GITHUB_PAT='your-personal-access-token'"
echo "   export GITHUB_EMAIL='your-email@example.com'"