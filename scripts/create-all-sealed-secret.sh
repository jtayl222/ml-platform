#!/bin/bash

# Make sure we're in the right directory
cd "$(dirname "$0")/.."

# Create MinIO secret for MinIO namespace
./scripts/create-sealed-secret.sh minio-credentials minio \
  access-key=minioadmin \
  secret-key=minioadmin123

# Create MinIO secret for argowf namespace (workflows need access)
./scripts/create-sealed-secret.sh minio-credentials-wf argowf \
  access-key=minioadmin \
  secret-key=minioadmin123

# Create Grafana secret for monitoring namespace
./scripts/create-sealed-secret.sh grafana-admin-secret monitoring \
  admin-password=admin123

# Create MinIO secret for Argo Workflows (correct namespace: argo)
./scripts/create-sealed-secret.sh minio-secret-wf argowf \
  AWS_ACCESS_KEY_ID=minioadmin \
  AWS_SECRET_ACCESS_KEY=minioadmin123 \
  AWS_ENDPOINT_URL=http://minio.minio.svc.cluster.local:9000 \
  AWS_DEFAULT_REGION=us-east-1 

# Create MinIO secret for Argo CD (correct namespace: argocd)
./scripts/create-sealed-secret.sh minio-secret-cd argocd \
  AWS_ACCESS_KEY_ID=minioadmin \
  AWS_SECRET_ACCESS_KEY=minioadmin123 \
  AWS_ENDPOINT_URL=http://minio.minio.svc.cluster.local:9000 \
  AWS_DEFAULT_REGION=us-east-1

# Create MLflow S3 secret for mlflow namespace
./scripts/create-sealed-secret.sh mlflow-s3-secret mlflow \
  AWS_ACCESS_KEY_ID=minioadmin \
  AWS_SECRET_ACCESS_KEY=minioadmin123 \
  MLFLOW_S3_ENDPOINT_URL=http://minio.minio.svc.cluster.local:9000

# Create Argo Workflows admin credentials secret
./scripts/create-sealed-secret.sh argo-workflows-admin argowf \
  username=admin \
  password=mlopsadmin123

# Create JupyterHub admin password secret  
./scripts/create-sealed-secret.sh jupyterhub-admin jupyterhub \
  password=mlops123

echo "All sealed secrets created successfully!"
echo ""
echo "Generated sealed secrets:"
echo "- MinIO credentials (minio, argowf namespaces)"
echo "- Grafana admin password (monitoring namespace)"
echo "- MLflow S3 credentials (mlflow namespace)"
echo "- Argo Workflows admin credentials (argowf namespace)"
echo "- JupyterHub admin password (jupyterhub namespace)"