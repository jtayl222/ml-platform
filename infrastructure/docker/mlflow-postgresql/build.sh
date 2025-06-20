#!/bin/bash
# MLflow PostgreSQL Image Build Script

set -e

# Configuration
IMAGE_NAME="jtayl22/mlflow-postgresql"
MLFLOW_VERSION="2.17.2"
TAG="${IMAGE_NAME}:${MLFLOW_VERSION}"

echo "🏗️  Building MLflow PostgreSQL image..."
echo "📦 Image: ${TAG}"

# Build the image
docker build -t "${TAG}" .

# Tag as latest
docker tag "${TAG}" "${IMAGE_NAME}:latest"

echo "✅ Build complete!"
echo "🚀 To push: docker push ${TAG}"
echo "🚀 To push latest: docker push ${IMAGE_NAME}:latest"

# Optional: Push if --push flag is provided
if [[ "$1" == "--push" ]]; then
    echo "📤 Pushing to registry..."
    docker push "${TAG}"
    docker push "${IMAGE_NAME}:latest"
    echo "✅ Push complete!"
fi
