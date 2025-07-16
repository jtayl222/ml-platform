#!/bin/bash

# Migrate Custom ML Platform Images to Harbor
# This script migrates your specific custom images to Harbor

set -e

HARBOR_REGISTRY=${HARBOR_REGISTRY:-"192.168.1.210"}
HARBOR_USER=${HARBOR_USER:-"admin"}
HARBOR_PASSWORD=${HARBOR_PASSWORD:-"Harbor12345"}

echo "🐳 Migrating Custom ML Platform Images to Harbor"
echo "==============================================="

# First, ensure you can reach Harbor
echo "Testing Harbor connectivity..."
curl -s -f -u $HARBOR_USER:$HARBOR_PASSWORD http://$HARBOR_REGISTRY/api/v2.0/systeminfo > /dev/null
if [ $? -ne 0 ]; then
    echo "❌ Cannot reach Harbor at http://$HARBOR_REGISTRY"
    echo "Please ensure Harbor is running and accessible"
    exit 1
fi
echo "✅ Harbor is accessible"

# Check if Docker daemon is configured for insecure registry
echo ""
echo "Checking Docker configuration..."
if ! grep -q "$HARBOR_REGISTRY" /etc/docker/daemon.json 2>/dev/null; then
    echo "❌ Docker is not configured for insecure registry $HARBOR_REGISTRY"
    echo "Please add to /etc/docker/daemon.json:"
    echo '{'
    echo '  "insecure-registries": ["'$HARBOR_REGISTRY'"]'
    echo '}'
    echo "Then restart Docker: sudo systemctl restart docker"
    exit 1
fi
echo "✅ Docker is configured for insecure registry"

# Login to Harbor
echo ""
echo "Logging into Harbor..."
echo $HARBOR_PASSWORD | docker login $HARBOR_REGISTRY -u $HARBOR_USER --password-stdin

# Create library project if it doesn't exist (using API)
echo ""
echo "Ensuring 'library' project exists in Harbor..."
curl -s -X POST -u $HARBOR_USER:$HARBOR_PASSWORD \
  -H "Content-Type: application/json" \
  -d '{"project_name": "library", "public": true}' \
  http://$HARBOR_REGISTRY/api/v2.0/projects 2>/dev/null || echo "Project may already exist"

# Function to migrate an image
migrate_image() {
    local source_image=$1
    local target_image=$2
    
    echo ""
    echo "📦 Migrating: $source_image"
    echo "   → Target: $target_image"
    
    # Pull from Docker Hub
    echo "   Pulling from Docker Hub..."
    docker pull $source_image
    
    # Tag for Harbor
    echo "   Tagging for Harbor..."
    docker tag $source_image $target_image
    
    # Push to Harbor
    echo "   Pushing to Harbor..."
    docker push $target_image
    
    echo "   ✅ Migration complete"
}

# Migrate your custom images
echo ""
echo "Starting image migration..."

# 1. Seldon Custom Agent (PR #6582)
migrate_image "jtayl22/seldon-agent:2.9.0-pr6582-test" "$HARBOR_REGISTRY/library/seldon-agent:2.9.0-pr6582-test"

# 2. MLflow with PostgreSQL
migrate_image "jtayl22/mlflow-postgresql:3.1.0-4" "$HARBOR_REGISTRY/library/mlflow-postgresql:3.1.0-4"

# 3. JupyterHub Financial Predictor
migrate_image "jtayl22/financial-predictor-jupyter:latest" "$HARBOR_REGISTRY/library/financial-predictor-jupyter:latest"

# 4. Common Seldon images
migrate_image "seldonio/mlserver:1.6.1" "$HARBOR_REGISTRY/library/mlserver:1.6.1"

# Summary
echo ""
echo "✅ Migration completed successfully!"
echo ""
echo "📋 Migrated images:"
echo "   - seldon-agent:2.9.0-pr6582-test"
echo "   - mlflow-postgresql:3.1.0-4"
echo "   - financial-predictor-jupyter:latest"
echo "   - mlserver:1.6.1"
echo ""
echo "🔧 Configuration has been updated in:"
echo "   - inventory/production/group_vars/all.yml"
echo ""
echo "📦 To apply changes, redeploy affected services:"
echo "   ansible-playbook -i inventory/production/hosts infrastructure/cluster/site.yml --tags seldon,mlflow,jupyter"
echo ""
echo "🧪 To verify images in Harbor:"
echo "   curl -s -u $HARBOR_USER:$HARBOR_PASSWORD http://$HARBOR_REGISTRY/api/v2.0/projects/library/repositories | jq"