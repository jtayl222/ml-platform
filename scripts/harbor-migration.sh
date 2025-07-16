#!/bin/bash

# Harbor Registry Migration Script
# This script pulls external images and pushes them to Harbor

set -e

HARBOR_REGISTRY=${HARBOR_REGISTRY:-"192.168.1.210"}
HARBOR_USER=${HARBOR_USER:-"admin"}
HARBOR_PASSWORD=${HARBOR_PASSWORD:-"Harbor12345"}

echo "🐳 Harbor Registry Migration Script"
echo "=================================="

# Configure Docker for insecure registry
echo "⚠️  NOTE: Harbor is configured with HTTP (insecure registry)"
echo "You need to add Harbor to Docker's insecure registries:"
echo ""
echo "1. Edit /etc/docker/daemon.json and add:"
echo '   {
     "insecure-registries": ["192.168.1.210"]
   }'
echo ""
echo "2. Restart Docker: sudo systemctl restart docker"
echo ""
echo "Press Enter when Docker is configured, or Ctrl+C to exit..."
read -r

# Login to Harbor
echo "Logging into Harbor registry..."
docker login $HARBOR_REGISTRY -u $HARBOR_USER -p $HARBOR_PASSWORD

# Create projects in Harbor (optional - can be done via UI)
echo "Note: Create 'library' project in Harbor UI if not exists"
echo "URL: http://$HARBOR_REGISTRY"

# 1. MLflow Custom Image
echo "📦 Migrating MLflow image..."
docker pull jtayl22/mlflow-postgresql:3.1.0-4
docker tag jtayl22/mlflow-postgresql:3.1.0-4 $HARBOR_REGISTRY/library/mlflow-postgresql:3.1.0-4
docker push $HARBOR_REGISTRY/library/mlflow-postgresql:3.1.0-4

# 2. JupyterHub Custom Image
echo "📦 Migrating JupyterHub image..."
docker pull jtayl22/financial-predictor-jupyter:latest
docker tag jtayl22/financial-predictor-jupyter:latest $HARBOR_REGISTRY/library/financial-predictor-jupyter:latest
docker push $HARBOR_REGISTRY/library/financial-predictor-jupyter:latest

# 3. Seldon Custom Agent Image
echo "📦 Migrating Seldon Agent image..."
docker pull jtayl22/seldon-agent:2.9.0-pr6582-test
docker tag jtayl22/seldon-agent:2.9.0-pr6582-test $HARBOR_REGISTRY/library/seldon-agent:2.9.0-pr6582-test
docker push $HARBOR_REGISTRY/library/seldon-agent:2.9.0-pr6582-test

# 4. Common utility images
echo "📦 Migrating utility images..."
docker pull python:3.11-slim
docker tag python:3.11-slim $HARBOR_REGISTRY/library/python:3.11-slim
docker push $HARBOR_REGISTRY/library/python:3.11-slim

docker pull minio/mc:latest
docker tag minio/mc:latest $HARBOR_REGISTRY/library/minio-mc:latest
docker push $HARBOR_REGISTRY/library/minio-mc:latest

docker pull nicolaka/netshoot
docker tag nicolaka/netshoot $HARBOR_REGISTRY/library/netshoot:latest
docker push $HARBOR_REGISTRY/library/netshoot:latest

# 5. Seldon Core images
echo "📦 Migrating Seldon Core images..."
docker pull seldonio/mlserver:1.6.1
docker tag seldonio/mlserver:1.6.1 $HARBOR_REGISTRY/library/mlserver:1.6.1
docker push $HARBOR_REGISTRY/library/mlserver:1.6.1

echo "✅ Harbor migration completed!"
echo ""
echo "🔧 Next steps:"
echo "1. Update inventory/production/group_vars/all.yml to use Harbor registry"
echo "2. Redeploy affected services with updated image references"
echo "3. Verify images are accessible in Harbor UI: http://$HARBOR_REGISTRY"