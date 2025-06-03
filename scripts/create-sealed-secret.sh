#!/bin/bash

# Usage: ./create-sealed-secret.sh secret-name namespace key1=value1 key2=value2

SECRET_NAME=$1
NAMESPACE=$2
shift 2

echo "Creating sealed secret: $SECRET_NAME in namespace: $NAMESPACE"

# Create the secret (dry-run)
kubectl create secret generic "$SECRET_NAME" \
  --namespace="$NAMESPACE" \
  $(printf -- "--from-literal=%s " "$@") \
  --dry-run=client -o yaml | \

kubeseal \
  --controller-name=sealed-secrets \
  --controller-namespace=kube-system \
  -o yaml > "infrastructure/manifests/sealed-secrets/${SECRET_NAME}.yaml"

echo "Sealed secret created: infrastructure/manifests/sealed-secrets/${SECRET_NAME}.yaml"