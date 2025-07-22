#!/bin/bash
# ml-platform/scripts/package-ml-secrets.sh
# Creates a complete package for development teams

set -e

WORKFLOW_NAME="$1"
ENVIRONMENTS="$2"  # dev,production
REQUESTOR="$3"

if [ -z "$WORKFLOW_NAME" ] || [ -z "$ENVIRONMENTS" ] || [ -z "$REQUESTOR" ]; then
    echo "Usage: $0 <workflow-name> <environments> <requestor>"
    echo "Example: $0 financial-mlops-pytorch dev,production financial-team@company.com"
    exit 1
fi

SCRIPT_DIR="$(dirname "$(realpath "$0")")"
ML_INFRASTRUCTURE_DIR="$(dirname "$SCRIPT_DIR")/infrastructure"
PACKAGE_DIR="$ML_INFRASTRUCTURE_DIR/packages/$WORKFLOW_NAME"

echo "Creating ML secrets package for: $WORKFLOW_NAME"
echo "Environments: $ENVIRONMENTS"

# Clean and create package directory
rm -rf "$PACKAGE_DIR"
mkdir -p "$PACKAGE_DIR"

IFS=',' read -ra ENV_ARRAY <<< "$ENVIRONMENTS"

# Generate secrets for each environment
for env in "${ENV_ARRAY[@]}"; do
    env=$(echo "$env" | xargs)
    
    if [ "$env" = "production" ]; then
        namespace="$WORKFLOW_NAME"
    else
        namespace="$WORKFLOW_NAME-$env"
    fi
    
    echo "Generating secrets for: $env (namespace: $namespace)"
    
    # Generate secrets
    "$SCRIPT_DIR/generate-ml-secrets.sh" "$namespace" "$REQUESTOR"
    
    # Create environment directory in package
    env_dir="$PACKAGE_DIR/$env"
    mkdir -p "$env_dir"
    
    # Copy secrets
    cp "$ML_INFRASTRUCTURE_DIR/manifests/sealed-secrets/$namespace"/*.yaml "$env_dir/"
    
    # Create simple kustomization for this environment
    cat > "$env_dir/kustomization.yaml" << EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: $namespace

resources:
  - ml-platform-sealed-secret.yaml
  - ghcr-sealed-secret.yaml
  - harbor-sealed-secret.yaml
  - seldon-rclone-sealed-secret.yaml
EOF

done

# Create a simple reference template
cat > "$PACKAGE_DIR/secret-reference-template.yaml" << EOF
# Template: How to reference ML secrets in your deployments
# Copy the relevant sections to your deployment.yaml

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
        # RECOMMENDED: Load all ML platform secrets as environment variables
        envFrom:
        - secretRef:
            name: ml-platform
        
        # Optional: Override or add specific environment variables
        env:
        - name: CUSTOM_VAR
          value: "custom-value"
        # Example: Override tracking URI if needed
        # - name: MLFLOW_TRACKING_URI  
        #   value: "http://custom-mlflow.example.com:5000"
      
      # For pulling private images from registries
      imagePullSecrets:
      - name: ghcr
      - name: harbor      # GitHub Container Registry
      - name: harbor    # Harbor registry

---
# Alternative: Using individual secret references (if you only need specific vars)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: your-ml-app-individual-refs
spec:
  template:
    spec:
      containers:
      - name: ml-container
        image: your-image
        env:
        # Individual secret references
        - name: AWS_ACCESS_KEY_ID
          valueFrom:
            secretKeyRef:
              name: ml-platform
              key: AWS_ACCESS_KEY_ID
        - name: AWS_SECRET_ACCESS_KEY
          valueFrom:
            secretKeyRef:
              name: ml-platform
              key: AWS_SECRET_ACCESS_KEY
        - name: MLFLOW_TRACKING_URI
          valueFrom:
            secretKeyRef:
              name: ml-platform
              key: MLFLOW_TRACKING_URI
        # Add other vars as needed...
      
      imagePullSecrets:
      - name: ghcr
      - name: harbor

---
# If using Kaniko for building images (push to GHCR)
apiVersion: v1
kind: Pod
metadata:
  name: kaniko-build-ghcr
spec:
  containers:
  - name: kaniko
    image: gcr.io/kaniko-project/executor:latest
    args:
    - --dockerfile=Dockerfile
    - --context=.
    - --destination=ghcr.io/your-org/your-image:tag
    volumeMounts:
    - name: docker-config
      mountPath: /kaniko/.docker
  volumes:
  - name: docker-config
    secret:
      secretName: ghcr
      items:
      - key: .dockerconfigjson
        path: config.json

---
# If using Kaniko for building images (push to Harbor)
apiVersion: v1
kind: Pod
metadata:
  name: kaniko-build-harbor
spec:
  containers:
  - name: kaniko
    image: gcr.io/kaniko-project/executor:latest
    args:
    - --dockerfile=Dockerfile
    - --context=.
    - --destination=harbor.test/library/your-image:tag
    volumeMounts:
    - name: docker-config
      mountPath: /kaniko/.docker
  volumes:
  - name: docker-config
    secret:
      secretName: harbor
      items:
      - key: .dockerconfigjson
        path: config.json
EOF

# Create README for development team
cat > "$PACKAGE_DIR/README.md" << EOF
# ML Secrets Package: $WORKFLOW_NAME

**Generated:** $(date)  
**Requestor:** $REQUESTOR  
**Environments:** $ENVIRONMENTS

## Quick Start

### 1. Apply Secrets to Your Namespaces

EOF

for env in "${ENV_ARRAY[@]}"; do
    env=$(echo "$env" | xargs)
    if [ "$env" = "production" ]; then
        namespace="$WORKFLOW_NAME"
    else
        namespace="$WORKFLOW_NAME-$env"
    fi
    
    cat >> "$PACKAGE_DIR/README.md" << EOF
**$env environment (namespace: \`$namespace\`):**
\`\`\`bash
kubectl apply -k $env/
\`\`\`

EOF
done

cat >> "$PACKAGE_DIR/README.md" << EOF
### 2. Reference in Your Applications

**Recommended approach using envFrom:**
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
            name: ml-platform  # Simple name!
      imagePullSecrets:
      - name: ghcr
      - name: harbor  # Simple name!
\`\`\`

See \`secret-reference-template.yaml\` for more examples.

## What's Included

EOF

for env in "${ENV_ARRAY[@]}"; do
    env=$(echo "$env" | xargs)
    if [ "$env" = "production" ]; then
        namespace="$WORKFLOW_NAME"
    else
        namespace="$WORKFLOW_NAME-$env"
    fi
    
    cat >> "$PACKAGE_DIR/README.md" << EOF
### $env/ 
- \`ml-platform-sealed-secret.yaml\` - Secret name: \`ml-platform\`
- \`ghcr-sealed-secret.yaml\` - Secret name: \`ghcr\`
- \`harbor-sealed-secret.yaml\` - Secret name: \`harbor\`
- \`seldon-rclone-sealed-secret.yaml\` - Secret name: \`seldon-rclone-gs-public\`
- \`kustomization.yaml\` - Ready-to-apply kustomization

EOF
done

cat >> "$PACKAGE_DIR/README.md" << EOF
## Available Environment Variables

When using \`envFrom\` with the \`ml-platform\` secret, these variables are automatically available:

- \`AWS_ACCESS_KEY_ID\` - MinIO access key
- \`AWS_SECRET_ACCESS_KEY\` - MinIO secret key  
- \`AWS_ENDPOINT_URL\` - MinIO endpoint
- \`AWS_DEFAULT_REGION\` - AWS region (us-east-1)
- \`MLFLOW_S3_ENDPOINT_URL\` - MLflow S3 endpoint
- \`MLFLOW_TRACKING_USERNAME\` - MLflow username
- \`MLFLOW_TRACKING_PASSWORD\` - MLflow password
- \`MLFLOW_FLASK_SERVER_SECRET_KEY\` - MLflow server secret
- \`MLFLOW_TRACKING_URI\` - MLflow tracking server URL

## Your Application Structure Recommendation

\`\`\`
your-app-repo/
├── k8s/
│   ├── base/
│   │   ├── kustomization.yaml
│   │   └── deployment.yaml  # Uses envFrom: secretRef: ml-platform
│   └── overlays/
│       ├── dev/
│       │   ├── kustomization.yaml
│       │   └── (secrets applied separately)
│       └── production/
│           ├── kustomization.yaml
│           └── (secrets applied separately)
\`\`\`

**Deploy Process:**
1. Apply secrets: \`kubectl apply -k path/to/secrets/dev/\`
2. Deploy app: \`kubectl apply -k k8s/overlays/dev/\`

## Support

- **Requestor:** $REQUESTOR
- **Infrastructure Team:** infrastructure-team@company.com
- **Platform Docs:** [Internal ML Platform Wiki]

## Secret Rotation

When secrets need rotation, contact the infrastructure team. We'll generate new sealed secrets and deliver them the same way.
EOF

# Create delivery package
ls $PACKAGE_DIR
(cd $PACKAGE_DIR; tar -czf "$ML_INFRASTRUCTURE_DIR/$WORKFLOW_NAME-ml-secrets-$(date +%Y%m%d).tar.gz" .)

echo ""
echo "✅ ML secrets package created!"
echo "📁 Package location: $PACKAGE_DIR"
echo "📦 Archive: $ML_INFRASTRUCTURE_DIR/$WORKFLOW_NAME-ml-secrets-$(date +%Y%m%d).tar.gz"
echo ""
echo "📧 Deliver to development team:"
echo "   - Send the archive file"
echo "   - Include the README.md for instructions"
echo ""
echo "Development team workflow:"
echo "1. Extract the archive"
echo "2. Apply secrets: kubectl apply -k dev/ (or production/)"
echo "3. Reference secrets using envFrom for simplicity"
