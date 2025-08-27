#!/bin/bash
# Run by infrastructure team with access to actual credentials

set -e

NAMESPACE="$1"
REQUESTOR="$2"

if [ -z "$NAMESPACE" ] || [ -z "$REQUESTOR" ]; then
    echo "Usage: $0 <namespace> <requestor-email>"
    echo "Example: $0 iris-demo data-team@company.com"
    exit 1
fi

OUTPUT_DIR=infrastructure/manifests/sealed-secrets/$1

# Verify namespace doesn't already exist or has approval
echo "Generating ML secrets for namespace: $NAMESPACE"
echo "Requestor: $REQUESTOR"
echo "Output directory: $OUTPUT_DIR"

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Source actual credentials (infrastructure team only)
# source /vault/ml-platform-credentials

# Function to seal and annotate secret
seal_and_annotate() {
    local output_file="$1"
    
    kubeseal \
        --controller-name=sealed-secrets \
        --controller-namespace=kube-system \
        -o yaml | \
    yq eval ".metadata.annotations.\"generated-by\" = \"infrastructure-team\"" | \
    yq eval ".metadata.annotations.\"generated-date\" = \"$(date -Iseconds)\"" | \
    yq eval ".metadata.annotations.\"approved-by\" = \"$REQUESTOR\"" | \
    yq eval ".metadata.annotations.\"namespace\" = \"$NAMESPACE\"" | \
    yq eval ".metadata.annotations.\"meta.helm.sh/release-name\" = \"infrastructure-secrets\"" | \
    yq eval ".metadata.annotations.\"meta.helm.sh/release-namespace\" = \"$NAMESPACE\"" | \
    yq eval ".metadata.labels.\"app.kubernetes.io/managed-by\" = \"infrastructure\"" | \
    yq eval ".spec.template.metadata.annotations.\"meta.helm.sh/release-name\" = \"infrastructure-secrets\"" | \
    yq eval ".spec.template.metadata.annotations.\"meta.helm.sh/release-namespace\" = \"$NAMESPACE\"" | \
    yq eval ".spec.template.metadata.labels.\"app.kubernetes.io/managed-by\" = \"infrastructure\"" \
    > "$output_file"
}

# Function to generate generic sealed secret
generate_generic_secret() {
    local secret_name="$1"
    local output_file="$2"
    shift 2
    
    echo "Generating generic sealed secret: $secret_name"
    
    kubectl create secret generic "$secret_name" \
        "$@" \
        --namespace="$NAMESPACE" \
        --dry-run=client -o yaml | \
    seal_and_annotate "$output_file"
    
    echo "Created: $output_file"
}

# Function to generate docker registry sealed secret
generate_docker_secret() {
    local secret_name="$1"
    local output_file="$2"
    local docker_server="$3"
    local docker_username="$4"
    local docker_password="$5"
    local docker_email="$6"
    
    echo "Generating docker registry sealed secret: $secret_name"
    
    kubectl create secret docker-registry "$secret_name" \
        --docker-server="$docker_server" \
        --docker-username="$docker_username" \
        --docker-password="$docker_password" \
        --docker-email="$docker_email" \
        --namespace="$NAMESPACE" \
        --dry-run=client -o yaml | \
    seal_and_annotate "$output_file"
    
    echo "Created: $output_file"
}

# Generate combined ML platform secret (MinIO + MLflow) - simplified name
generate_generic_secret \
    "ml-platform" \
    "$OUTPUT_DIR/ml-platform-sealed-secret.yaml" \
    --from-literal=AWS_ACCESS_KEY_ID="$MINIO_ACCESS_KEY" \
    --from-literal=AWS_SECRET_ACCESS_KEY="$MINIO_SECRET_KEY" \
    --from-literal=AWS_ENDPOINT_URL="http://minio.minio.svc.cluster.local:9000" \
    --from-literal=AWS_DEFAULT_REGION="us-east-1" \
    --from-literal=MLFLOW_S3_ENDPOINT_URL="http://minio.minio.svc.cluster.local:9000" \
    --from-literal=MLFLOW_TRACKING_USERNAME="$MLFLOW_TRACKING_USERNAME" \
    --from-literal=MLFLOW_TRACKING_PASSWORD="$MLFLOW_TRACKING_PASSWORD" \
    --from-literal=MLFLOW_FLASK_SERVER_SECRET_KEY="$MLFLOW_FLASK_SECRET_KEY" \
    --from-literal=MLFLOW_TRACKING_URI="http://mlflow.mlflow.svc.cluster.local:5000" \
    --from-literal=RCLONE_CONFIG_S3_TYPE="s3" \
    --from-literal=RCLONE_CONFIG_S3_PROVIDER="Minio" \
    --from-literal=RCLONE_CONFIG_S3_ACCESS_KEY_ID="$MINIO_ACCESS_KEY" \
    --from-literal=RCLONE_CONFIG_S3_SECRET_ACCESS_KEY="$MINIO_SECRET_KEY" \
    --from-literal=RCLONE_CONFIG_S3_ENDPOINT="http://minio.minio.svc.cluster.local:9000" \
    --from-literal=RCLONE_CONFIG_S3_REGION="us-east-1"

# Generate GHCR secret (separate due to different structure) - simplified name
generate_docker_secret \
    "ghcr" \
    "$OUTPUT_DIR/ghcr-sealed-secret.yaml" \
    "ghcr.io" \
    "$GITHUB_USERNAME" \
    "$GITHUB_PAT" \
    "$GITHUB_EMAIL"

# Generate Harbor registry secret - simplified name
generate_docker_secret \
    "harbor" \
    "$OUTPUT_DIR/harbor-sealed-secret.yaml" \
    "harbor.test" \
    "admin" \
    "Harbor12345" \
    "admin@harbor.local"

# Generate Seldon RClone secret (required by Seldon Core v2 for S3 model loading)
generate_generic_secret \
    "seldon-rclone-gs-public" \
    "$OUTPUT_DIR/seldon-rclone-sealed-secret.yaml" \
    --from-literal=rclone.conf="{
  \"name\": \"s3\",
  \"type\": \"s3\",
  \"parameters\": {
    \"provider\": \"Minio\",
    \"access_key_id\": \"$MINIO_ACCESS_KEY\",
    \"secret_access_key\": \"$MINIO_SECRET_KEY\",
    \"endpoint\": \"http://minio.minio.svc.cluster.local:9000\",
    \"region\": \"us-east-1\"
  }
}"

# Create a README for the development team
cat > "$OUTPUT_DIR/README.md" << EOF
# ML Secrets for Namespace: $NAMESPACE

Generated on: $(date)
Requestor: $REQUESTOR
Generated by: Infrastructure Team

## Files Included:
- ml-platform-sealed-secret.yaml - Combined ML platform credentials (MinIO + MLflow)
- ghcr-sealed-secret.yaml - GitHub Container Registry credentials
- harbor-sealed-secret.yaml - Harbor container registry credentials
- seldon-rclone-sealed-secret.yaml - Seldon Core RClone configuration for S3 model loading

## Usage:
1. Apply these sealed secrets to your namespace:
   \`\`\`bash
   kubectl apply -f ml-platform-sealed-secret.yaml
   kubectl apply -f ghcr-sealed-secret.yaml
   kubectl apply -f harbor-sealed-secret.yaml
   kubectl apply -f seldon-rclone-sealed-secret.yaml
   \`\`\`

2. Reference in your deployments using envFrom (recommended):
   \`\`\`yaml
   apiVersion: apps/v1
   kind: Deployment
   metadata:
     name: your-ml-app
   spec:
     template:
       spec:
         containers:
         - name: ml-container
           image: your-image
           envFrom:
           - secretRef:
               name: ml-platform
         # For pulling private images from registries
         imagePullSecrets:
         - name: ghcr      # For GitHub Container Registry images
         - name: harbor    # For Harbor registry images
   \`\`\`

3. Alternative: Reference individual keys (if needed):
   \`\`\`yaml
   env:
   - name: AWS_ACCESS_KEY_ID
     valueFrom:
       secretKeyRef:
         name: ml-platform
         key: AWS_ACCESS_KEY_ID
   \`\`\`

## Available Environment Variables:
When using \`envFrom\`, these variables will be automatically available:
- AWS_ACCESS_KEY_ID
- AWS_SECRET_ACCESS_KEY  
- AWS_ENDPOINT_URL
- AWS_DEFAULT_REGION
- MLFLOW_S3_ENDPOINT_URL
- MLFLOW_TRACKING_USERNAME
- MLFLOW_TRACKING_PASSWORD
- MLFLOW_FLASK_SERVER_SECRET_KEY
- MLFLOW_TRACKING_URI

## Security Notes:
- These sealed secrets can ONLY be decrypted in the '$NAMESPACE' namespace
- Do not attempt to move them to other namespaces
- Contact infrastructure team for rotations or issues
- These secrets are encrypted and safe to store in Git

## Support:
Contact: infrastructure-team@company.com
Slack: #infrastructure-support
EOF

echo ""
echo "✅ Secrets generated successfully!"
echo "📁 Files created in: $OUTPUT_DIR"
echo "📧 Deliver these files to: $REQUESTOR"
echo ""
echo "Files generated:"
ls -la "$OUTPUT_DIR"

# Optional: Create a delivery package
(cd "$OUTPUT_DIR" && tar -czf ml-secrets-package.tar.gz *.md *.yaml)
echo "📦 Package created: $OUTPUT_DIR/ml-secrets-package.tar.gz"
