#!/bin/bash

# Create sealed secret for Docker registry credentials
# Usage: ./create-sealed-docker-secret.sh <secret-name> <namespace> <registry-server> <username> <password> <email>

SECRET_NAME=$1
NAMESPACE=$2
DOCKER_SERVER=$3
DOCKER_USERNAME=$4
DOCKER_PASSWORD=$5
DOCKER_EMAIL=${6:-"noreply@example.com"}

if [ $# -lt 5 ]; then
    echo "Usage: $0 <secret-name> <namespace> <registry-server> <username> <password> [email]"
    echo "Example: $0 ghcr-credentials argowf ghcr.io myuser mytoken user@example.com"
    exit 1
fi

echo "Creating sealed Docker registry secret: $SECRET_NAME in namespace: $NAMESPACE"

# Create the docker-registry secret
kubectl create secret docker-registry "$SECRET_NAME" \
  --docker-server="$DOCKER_SERVER" \
  --docker-username="$DOCKER_USERNAME" \
  --docker-password="$DOCKER_PASSWORD" \
  --docker-email="$DOCKER_EMAIL" \
  -n $NAMESPACE \
  --dry-run=client -o yaml > "temp-${SECRET_NAME}.yaml"

# Seal it with namespace specification
kubeseal -f "temp-${SECRET_NAME}.yaml" \
  --controller-name=sealed-secrets \
  --controller-namespace=kube-system \
  --scope cluster-wide \
  -w "infrastructure/manifests/sealed-secrets/${SECRET_NAME}.yaml"

# Clean up temporary file
rm "temp-${SECRET_NAME}.yaml"

