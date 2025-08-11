# Sealed Secrets Role

Ansible role for deploying and managing Bitnami Sealed Secrets controller for GitOps-safe secret management in Kubernetes.

## Overview

Sealed Secrets provides **asymmetric encryption for Kubernetes secrets** that can be safely stored in Git repositories. This role:
- **Deploys Controller** - Installs Bitnami Sealed Secrets via Helm
- **Creates Namespaces** - Prepares application namespaces for sealed secrets
- **Generates Secrets** - Automatically creates platform secrets via scripts
- **Applies Manifests** - Deploys sealed secret manifests to the cluster

## Architecture

```
🔐 Sealed Secrets Security Model
├── 🔑 Controller (kube-system)
│   ├── Bitnami Sealed Secrets Operator
│   ├── Private/Public Key Pair (auto-generated)
│   ├── CRD: SealedSecret → Secret conversion
│   └── Namespace-scoped decryption
├── 📜 Sealed Secret Manifests (Git-safe)
│   ├── Encrypted with controller's public key
│   ├── Can be committed to version control
│   ├── Only decryptable by target cluster
│   └── Namespace + name scoped for security
└── 🎯 Runtime Secrets (Kubernetes)
    ├── Auto-created by controller
    ├── Standard Kubernetes secrets
    ├── Consumed by applications
    └── Automatically rotated on manifest changes
```

## Features

- ✅ **Asymmetric Encryption** - RSA 4096-bit public key encryption
- ✅ **GitOps Ready** - Sealed secrets can be safely committed to Git
- ✅ **Namespace Scoped** - Secrets only decrypt in target namespace
- ✅ **Automated Generation** - Platform secrets created via scripts
- ✅ **Self-Healing** - Controller automatically recreates secrets
- ✅ **Version Control** - Track secret changes via Git commits
- ✅ **Cluster Scoped** - Secrets tied to specific cluster private key

## Requirements

### Dependencies
- Kubernetes cluster with Helm support
- `kubeconfig_path` variable pointing to valid kubeconfig
- Internet connectivity for downloading Helm charts
- Ansible collections:
  - `kubernetes.core`

### Minimum Versions
- **Kubernetes**: 1.19+
- **Sealed Secrets Controller**: 0.18+
- **Helm**: 3.0+

## Role Variables

### Required Variables
```yaml
kubeconfig_path: /path/to/kubeconfig  # Path to cluster kubeconfig
```

### Optional Variables
```yaml
# Deployment Configuration
sealed_secrets_namespace: kube-system        # Controller namespace
sealed_secrets_chart_version: ""             # Helm chart version (latest)

# State Management  
k3s_state: present                           # present|absent
```

### Environment Variables (for script generation)
```bash
# MinIO Object Storage
export MINIO_ACCESS_KEY="minioadmin"
export MINIO_SECRET_KEY="minioadmin123"

# GitHub Integration
export GITHUB_USERNAME="your-username"
export GITHUB_PAT="ghp_your_token"
export GITHUB_EMAIL="your-email@example.com"

# MLflow Authentication
export MLFLOW_TRACKING_USERNAME="mlflow"
export MLFLOW_TRACKING_PASSWORD="secure-password"
export MLFLOW_DB_USERNAME="mlflow_user"
export MLFLOW_DB_PASSWORD="db-password"
export MLFLOW_FLASK_SECRET_KEY="$(openssl rand -base64 32)"
```

## Deployment

### 1. Basic Deployment
```bash
# Deploy Sealed Secrets controller and platform secrets
ansible-playbook -i inventory/production/hosts infrastructure/cluster/site.yml --tags="sealed-secrets"
```

### 2. Controller Only
```bash
# Deploy only the controller (no secret generation)
ansible-playbook site.yml --tags="sealed-secrets,controller"
```

### 3. Secrets Only
```bash
# Generate and apply sealed secrets (controller must exist)
ansible-playbook site.yml --tags="sealed-secrets,scripts,manifests"
```

### 4. Namespace Preparation
```bash
# Create namespaces for sealed secrets
ansible-playbook site.yml --tags="sealed-secrets,namespaces"
```

## Available Tags

- `sealed-secrets` - All sealed secrets tasks
- `controller` - Sealed Secrets controller deployment
- `helm` - Helm repository and chart installation
- `namespaces` - Namespace creation and preparation
- `scripts` - Script-based secret generation
- `generation` - Secret generation tasks
- `manifests` - Sealed secret manifest deployment
- `secrets` - Secret-related tasks
- `prerequisites` - Validation and prerequisite checks
- `validation` - Validation tasks

## Platform Secrets

### Automatically Generated Secrets

The role creates sealed secrets for all platform components:

#### MinIO Object Storage
```yaml
# minio-credentials.yaml (minio namespace)
access-key: <encrypted-access-key>
secret-key: <encrypted-secret-key>
```

#### MLflow Tracking Server
```yaml
# mlflow-s3-secret.yaml (mlflow namespace)
AWS_ACCESS_KEY_ID: <encrypted-key>
AWS_SECRET_ACCESS_KEY: <encrypted-secret>

# mlflow-basic-auth.yaml (mlflow namespace)  
MLFLOW_TRACKING_USERNAME: <encrypted-username>
MLFLOW_TRACKING_PASSWORD: <encrypted-password>
MLFLOW_FLASK_SERVER_SECRET_KEY: <encrypted-flask-key>

# mlflow-db-credentials.yaml (mlflow namespace)
username: <encrypted-db-username>
password: <encrypted-db-password>
```

#### Argo Workflows
```yaml
# Generated via scripts/generate-ml-secrets.sh
# Multiple ML project secrets with unique access keys
```

#### ArgoCD
```yaml
# minio-secret-cd.yaml (argocd namespace)
AWS_ACCESS_KEY_ID: <encrypted-key>
AWS_SECRET_ACCESS_KEY: <encrypted-secret>
AWS_ENDPOINT_URL: <encrypted-endpoint>

# argocd-admin-secret.yaml (argocd namespace)
admin-password: <encrypted-password>
```

#### JupyterHub
```yaml
# Harbor registry secrets and authentication
# Generated for notebook environments
```

## Manual Secret Creation

### Using the CLI Tool
```bash
# Install kubeseal CLI
wget https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.18.0/kubeseal-0.18.0-linux-amd64.tar.gz
tar -xvzf kubeseal-0.18.0-linux-amd64.tar.gz
sudo install -m 755 kubeseal /usr/local/bin/kubeseal

# Create a sealed secret
echo -n mypassword | kubectl create secret generic mysecret --dry-run=client --from-file=password=/dev/stdin -o yaml | kubeseal -o yaml > mysealedsecret.yaml

# Apply the sealed secret
kubectl apply -f mysealedsecret.yaml
```

### Using Platform Scripts
```bash
# Create individual sealed secret
./scripts/create-sealed-secret.sh secret-name namespace key1=value1 key2=value2

# Generate ML project secrets
./scripts/generate-ml-secrets.sh project-name team@company.com

# Create all platform secrets
./scripts/create-all-sealed-secrets.sh
```

## File Locations

```bash
# Controller Components
/var/lib/sealed-secrets/           # Controller data directory
/etc/sealed-secrets/               # Controller configuration

# Generated Manifests
infrastructure/manifests/sealed-secrets/  # All sealed secret manifests
├── minio-credentials.yaml
├── mlflow-s3-secret.yaml
├── mlflow-basic-auth.yaml
├── mlflow-db-credentials.yaml
├── argocd-admin-secret.yaml
└── project-*.yaml

# Generation Scripts
scripts/create-sealed-secret.sh           # Individual secret creation
scripts/create-all-sealed-secrets.sh      # Platform secret generation
scripts/generate-ml-secrets.sh            # ML project secret generation
```

## Security Considerations

### ✅ Security Features
- **Asymmetric Encryption** - RSA 4096-bit keys, impossible to decrypt without private key
- **Namespace Scoping** - Secrets only decrypt in intended namespace
- **Name Scoping** - Secrets tied to specific secret name
- **Git Safe** - Encrypted secrets can be committed to version control
- **Cluster Binding** - Secrets only work on cluster with matching private key
- **Automatic Rotation** - Reapplying manifest rotates the secret

### ⚠️ Security Considerations
- **Private Key Protection** - Controller private key is cluster's root of trust
- **Backup Strategy** - Private key loss means all secrets become unrecoverable
- **Secret Visibility** - Decrypted secrets are standard Kubernetes secrets
- **Namespace Trust** - Any admin in target namespace can read decrypted secrets

### 🔐 Best Practices
```bash
# Backup controller private key
kubectl get secret -n kube-system sealed-secrets-key -o yaml > sealed-secrets-backup.yaml

# Rotate secrets regularly
kubectl delete secret mysecret -n mynamespace
kubectl apply -f mysealedsecret.yaml

# Use strong encryption
export SEALED_SECRETS_ALGORITHM=RSA-OAEP
```

## Troubleshooting

### Common Issues

#### 1. Controller Not Ready
```bash
# Check controller status
kubectl get pods -n kube-system | grep sealed-secrets
kubectl logs -n kube-system deployment/sealed-secrets

# Check if controller is responding
kubectl get sealedsecrets --all-namespaces
```

#### 2. Secrets Not Decrypting
```bash
# Check sealed secret status
kubectl describe sealedsecret mysecret -n mynamespace

# Check if namespace exists
kubectl get ns mynamespace

# Verify secret was created
kubectl get secret mysecret -n mynamespace
```

#### 3. Script Failures
```bash
# Check script permissions
ls -la scripts/create-all-sealed-secrets.sh

# Run script manually
cd infrastructure/cluster
../../scripts/create-all-sealed-secrets.sh

# Check environment variables
echo $MINIO_ACCESS_KEY
echo $MLFLOW_TRACKING_USERNAME
```

#### 4. Kubeseal CLI Issues
```bash
# Test kubeseal connectivity
kubeseal --controller-name=sealed-secrets --controller-namespace=kube-system --fetch-cert

# Manual secret encryption
echo -n secret-value | kubeseal --raw --from-file=/dev/stdin --name=secret-name --namespace=target-namespace
```

### Health Checks
```bash
# Verify controller deployment
kubectl get deployment sealed-secrets -n kube-system
kubectl get pods -l name=sealed-secrets -n kube-system

# Test secret creation workflow
kubectl create secret generic test-secret --from-literal=key=value --dry-run=client -o yaml | kubeseal -o yaml > test-sealed.yaml
kubectl apply -f test-sealed.yaml
kubectl get secret test-secret

# Check public certificate
kubeseal --fetch-cert --controller-namespace=kube-system
```

## Integration

### MLOps Platform Integration
```yaml
# MLflow uses multiple sealed secrets
spec:
  containers:
  - name: mlflow
    env:
    - name: AWS_ACCESS_KEY_ID
      valueFrom:
        secretKeyRef:
          name: mlflow-s3-secret
          key: AWS_ACCESS_KEY_ID
    - name: MLFLOW_TRACKING_USERNAME
      valueFrom:
        secretKeyRef:
          name: mlflow-basic-auth
          key: MLFLOW_TRACKING_USERNAME
```

### ArgoCD Integration
```yaml
# ArgoCD uses sealed secrets for repository access
apiVersion: v1
kind: Secret
metadata:
  name: repository-secret
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: repository
type: Opaque
data:
  # Automatically decrypted from sealed secret
  username: <base64-username>
  password: <base64-password>
```

### Argo Workflows Integration
```yaml
# Workflow templates reference sealed secrets
spec:
  templates:
  - name: ml-training
    container:
      env:
      - name: MLFLOW_TRACKING_URI
        value: "http://mlflow.mlflow.svc.cluster.local:5000"
      - name: AWS_ACCESS_KEY_ID
        valueFrom:
          secretKeyRef:
            name: ml-project-s3-secret
            key: AWS_ACCESS_KEY_ID
```

## Backup and Recovery

### Controller Backup
```bash
# Backup sealed secrets controller key
kubectl get secret sealed-secrets-key -n kube-system -o yaml > sealed-secrets-controller-backup.yaml

# Store backup securely (outside cluster)
gpg --symmetric --cipher-algo AES256 sealed-secrets-controller-backup.yaml
```

### Cluster Migration
```bash
# Restore controller key to new cluster
kubectl apply -f sealed-secrets-controller-backup.yaml

# Redeploy controller
helm upgrade sealed-secrets sealed-secrets/sealed-secrets -n kube-system

# Reapply all sealed secrets
kubectl apply -f infrastructure/manifests/sealed-secrets/
```

### Secret Rotation
```bash
# Rotate individual secret
./scripts/create-sealed-secret.sh secret-name namespace key=new-value
kubectl apply -f infrastructure/manifests/sealed-secrets/secret-name.yaml

# Rotate all platform secrets
./scripts/create-all-sealed-secrets.sh
```

## Links

- [Sealed Secrets Documentation](https://sealed-secrets.netlify.app/)
- [Bitnami Sealed Secrets GitHub](https://github.com/bitnami-labs/sealed-secrets)
- [Helm Chart Repository](https://github.com/bitnami-labs/sealed-secrets/tree/main/helm/sealed-secrets)
- [GitOps Best Practices](https://www.gitops.tech/)

---

**Part of the K3s Homelab MLOps Platform** | [Main Documentation](../../README.md)