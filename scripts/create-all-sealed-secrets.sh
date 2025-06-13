#!/bin/bash

# Make sure we're in the right directory
cd "$(dirname "$0")/.."

echo "Creating all sealed secrets for K3s homelab..."

# Create MinIO secret for MinIO namespace
./scripts/create-sealed-secret.sh minio-credentials minio \
  access-key=minioadmin \
  secret-key=minioadmin123

#vMinIO secret for argowf namespace (workflows need access)
./scripts/create-sealed-secret.sh minio-credentials-wf argowf \
  access-key=minioadmin \
  secret-key=minioadmin123 \
  AWS_ACCESS_KEY_ID=minioadmin \
  AWS_SECRET_ACCESS_KEY=minioadmin123 \
  AWS_ENDPOINT_URL=http://minio.minio.svc.cluster.local:9000 \
  AWS_DEFAULT_REGION=us-east-1 \
  MLFLOW_S3_ENDPOINT_URL=http://minio.minio.svc.cluster.local:9000

# Create Grafana secret for monitoring namespace
./scripts/create-sealed-secret.sh grafana-admin-secret monitoring \
  admin-password=admin123

# Create MinIO secret for Argo CD (AWS S3 compatible format)
./scripts/create-sealed-secret.sh minio-secret-cd argocd \
  AWS_ACCESS_KEY_ID=minioadmin \
  AWS_SECRET_ACCESS_KEY=minioadmin123 \
  AWS_ENDPOINT_URL=http://minio.minio.svc.cluster.local:9000 \
  AWS_DEFAULT_REGION=us-east-1

# Create MLflow S3 secret for mlflow namespace
./scripts/create-sealed-secret.sh mlflow-s3-secret mlflow \
  AWS_ACCESS_KEY_ID=minioadmin \
  AWS_SECRET_ACCESS_KEY=minioadmin123 \
  MLFLOW_S3_ENDPOINT_URL=http://minio.minio.svc.cluster.local:9000 \
  AWS_DEFAULT_REGION=us-east-1

# Create JupyterHub admin password secret  
./scripts/create-sealed-secret.sh jupyterhub-admin jupyterhub \
  password=mlops123

# Create ArgoCD admin password secret
./scripts/create-sealed-secret.sh argocd-admin-secret argocd \
  admin-password=admin123  

# GitHub Container Registry credentials - FIXED
# Replace 'jtayl222' with your GitHub username and 'ghp_xxxx' with your GitHub PAT
./scripts/create-sealed-docker-secret.sh ghcr-credentials argowf \
  ghcr.io \
  jtayl222 \
  ghp_... \
  your-email@example.com  
