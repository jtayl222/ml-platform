# Argo CD Role

Ansible role for deploying Argo CD GitOps platform on K3s clusters with minimal configuration.

## Overview

Argo CD provides **GitOps continuous deployment** for Kubernetes applications. This role:
- **Deploys Argo CD** - Minimal installation via Helm
- **NodePort Access** - External access via port 30080
- **LoadBalancer Support** - Optional MetalLB integration
- **Basic Configuration** - Simple deployment without complex authentication

## Architecture

```
📱 Argo CD Minimal Deployment
├── 🎛️ Argo CD Server
│   ├── Web UI on port 8080
│   ├── REST API for CLI access
│   ├── Git repository synchronization
│   └── Application lifecycle management
├── 🗄️ Argo CD Repository Server
│   ├── Git repository cloning
│   ├── Manifest generation
│   └── Helm chart processing
├── 🎯 Argo CD Application Controller
│   ├── Application monitoring
│   ├── Sync status tracking
│   └── Resource deployment
├── 🔐 Argo CD DEX Server
│   └── Basic authentication
└── 💾 Argo CD Redis
    └── Caching and sessions
```

## Features

- ✅ **GitOps Deployment** - Declarative application management
- ✅ **Web UI** - Graphical interface for managing applications
- ✅ **CLI Access** - Command-line interface for automation
- ✅ **NodePort Service** - External access without ingress
- ✅ **LoadBalancer Support** - MetalLB integration for stable IPs
- ✅ **Helm Integration** - Deploy and manage Helm charts
- ✅ **Multi-Source Apps** - Support for multiple Git repositories

## Requirements

### Dependencies
- K3s cluster with Helm support
- `kubeconfig_path` variable pointing to valid kubeconfig
- Internet connectivity for downloading Helm charts
- Ansible collections:
  - `kubernetes.core`

### Minimum Versions
- **Kubernetes**: 1.19+
- **Argo CD**: 2.0+
- **Helm**: 3.0+

## Role Variables

### Required Variables
```yaml
kubeconfig_path: /path/to/kubeconfig  # Path to cluster kubeconfig
```

### Default Variables
```yaml
# Deployment Configuration
argocd_namespace: argocd              # Kubernetes namespace
argocd_name: argocd                   # Helm release name
argocd_chart_ref: argo/argo-cd        # Helm chart reference
argocd_nodeport: 30080                # NodePort for external access
helm_wait_timeout: 600s              # Helm deployment timeout
```

### MetalLB Configuration
```yaml
# LoadBalancer IP (when MetalLB is enabled)
metallb_state: present               # Enable LoadBalancer services
# Fixed IP: 192.168.1.204 (configured in role)
```

## Deployment

### 1. Basic Deployment
```bash
# Deploy Argo CD with default configuration
ansible-playbook -i inventory/production/hosts infrastructure/cluster/site.yml --tags="argocd"
```

### 2. Platform Deployment
```bash
# Deploy as part of platform stack
ansible-playbook site.yml --tags="platform"
```

### 3. Custom Port
```bash
# Deploy with custom NodePort
ansible-playbook site.yml --tags="argocd" -e "argocd_nodeport=31080"
```

### 4. With MetalLB
```bash
# Deploy with LoadBalancer service
ansible-playbook site.yml --tags="argocd" -e "metallb_state=present"
```

## Available Tags

- `argocd` - All Argo CD related tasks
- `platform` - Platform component deployment
- `helm-repos` - Helm repository management
- `loadbalancer` - LoadBalancer service creation
- `summary` - Deployment status display

## Access

### Web UI Access
```bash
# NodePort Access (default)
URL: http://192.168.1.85:30080

# LoadBalancer Access (with MetalLB)
URL: http://192.168.1.204

# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

### CLI Access
```bash
# Install Argo CD CLI
curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd

# Login via CLI
argocd login 192.168.1.85:30080

# Alternative: LoadBalancer
argocd login 192.168.1.204
```

## Basic Usage

### Create Application
```bash
# Via CLI
argocd app create guestbook \
  --repo https://github.com/argoproj/argocd-example-apps.git \
  --path guestbook \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace default

# Sync application
argocd app sync guestbook
```

### Application YAML
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: guestbook
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/argoproj/argocd-example-apps.git
    targetRevision: HEAD
    path: guestbook
  destination:
    server: https://kubernetes.default.svc
    namespace: default
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

## Network Configuration

### Service Ports
```bash
# Argo CD Services
8080/tcp     # Argo CD server (internal)
30080/tcp    # NodePort external access
80/tcp       # LoadBalancer HTTP (MetalLB)
443/tcp      # LoadBalancer HTTPS (MetalLB)

# Internal Services
8081/tcp     # Argo CD metrics
8082/tcp     # Argo CD application controller metrics
8083/tcp     # Argo CD repository server metrics
```

### Firewall Configuration
```bash
# Allow NodePort access
sudo ufw allow 30080/tcp comment 'Argo CD NodePort'

# For LoadBalancer (MetalLB handles external access)
# No additional firewall rules needed
```

## Integration

### MLOps Platform
```yaml
# Argo CD manages ML applications
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: mlflow
  namespace: argocd
spec:
  source:
    repoURL: https://github.com/your-org/ml-platform.git
    path: applications/mlflow
    targetRevision: main
  destination:
    server: https://kubernetes.default.svc
    namespace: mlflow
```

### Seldon Core Integration
```yaml
# Deploy ML models via GitOps
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: fraud-detection-model
  namespace: argocd
spec:
  source:
    repoURL: https://github.com/your-org/ml-models.git
    path: fraud-detection
    targetRevision: main
  destination:
    server: https://kubernetes.default.svc
    namespace: fraud-detection
```

### Harbor Registry Integration
```yaml
# Use Harbor for private repositories
apiVersion: v1
kind: Secret
metadata:
  name: harbor-repo-secret
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: repository
type: Opaque
stringData:
  type: git
  url: https://harbor.local/project/repo.git
  username: robot$argocd
  password: token-from-harbor
```

## Troubleshooting

### Common Issues

#### 1. Argo CD Server Not Accessible
```bash
# Check service status
kubectl get svc -n argocd

# Check pod status
kubectl get pods -n argocd
kubectl logs -n argocd deployment/argocd-server

# Test NodePort connectivity
curl -k http://192.168.1.85:30080
```

#### 2. LoadBalancer Not Working
```bash
# Check MetalLB status
kubectl get pods -n metallb-system

# Verify LoadBalancer service
kubectl get svc -n argocd argocd-server
kubectl describe svc -n argocd argocd-server

# Check IP assignment
ping 192.168.1.204
```

#### 3. Application Sync Issues
```bash
# Check application status
argocd app get <app-name>
argocd app logs <app-name>

# Check repository access
kubectl logs -n argocd deployment/argocd-repo-server

# Verify Git repository connectivity
kubectl exec -n argocd deployment/argocd-repo-server -- git ls-remote <repo-url>
```

#### 4. Authentication Problems
```bash
# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Reset admin password
argocd account update-password --account admin --current-password <current> --new-password <new>

# Check user accounts
argocd account list
```

### Health Checks
```bash
# Check all Argo CD components
kubectl get all -n argocd

# Verify server health
curl -k http://192.168.1.85:30080/healthz

# Check application status
argocd app list
argocd app get <app-name>

# Monitor sync status
argocd app wait <app-name> --health
```

## File Structure

```bash
infrastructure/cluster/roles/platform/argo_cd/
├── defaults/
│   └── main.yml                    # Default variables
├── tasks/
│   └── main.yml                    # Main deployment tasks
└── README.md                       # This file
```

## Security Considerations

### ✅ Security Features
- **RBAC** - Role-based access control enabled by default
- **TLS** - HTTPS encryption for web UI
- **Service Account** - Dedicated service accounts for components
- **Network Policies** - Optional network isolation

### ⚠️ Security Considerations
- **Default Admin** - Change default admin password
- **Repository Access** - Secure Git repository credentials
- **Cluster Permissions** - Argo CD has cluster-admin by default
- **External Access** - NodePort exposes service externally

### 🔐 Best Practices
```bash
# Change admin password
argocd account update-password

# Create application-specific projects
argocd proj create myproject

# Use least-privilege RBAC
argocd account create readonly
argocd account add-policy readonly --policy-file readonly-policy.csv
```

## Updates and Maintenance

### Update Argo CD
```bash
# Update Helm chart
ansible-playbook site.yml --tags="argocd"

# Check version
argocd version
```

### Backup Configuration
```bash
# Export applications
argocd app list -o yaml > applications-backup.yaml

# Export projects
argocd proj list -o yaml > projects-backup.yaml

# Backup secrets
kubectl get secrets -n argocd -o yaml > argocd-secrets-backup.yaml
```

### Restore Configuration
```bash
# Restore applications
kubectl apply -f applications-backup.yaml

# Restore projects
kubectl apply -f projects-backup.yaml
```

## Links

- [Argo CD Documentation](https://argo-cd.readthedocs.io/)
- [Argo CD Helm Chart](https://github.com/argoproj/argo-helm/tree/main/charts/argo-cd)
- [GitOps Principles](https://www.gitops.tech/)
- [Argo CD CLI Reference](https://argo-cd.readthedocs.io/en/stable/cli_installation/)

---

**Part of the K3s Homelab MLOps Platform** | [Main Documentation](../../README.md)