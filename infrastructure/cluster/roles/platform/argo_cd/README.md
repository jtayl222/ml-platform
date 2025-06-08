# ArgoCD Platform Role

**GitOps continuous deployment platform for Kubernetes applications**

## 🎯 **Overview**

This Ansible role deploys ArgoCD on your K3s cluster, providing enterprise-grade GitOps capabilities for continuous deployment. ArgoCD enables declarative configuration management, automated synchronization, and complete visibility into your application deployments.

## 🏗️ **What This Role Deploys**

### **Core ArgoCD Components**
- **ArgoCD Server** - Web UI and API server
- **ArgoCD Repository Server** - Git repository management
- **ArgoCD Application Controller** - Application lifecycle management
- **ArgoCD DEX Server** - Authentication and SSO integration
- **ArgoCD Redis** - Caching and session storage

### **Access & Networking**
- **NodePort Service** (port 30080) for web UI access
- **HTTPS/TLS** enabled by default
- **Admin user** with auto-generated password
- **RBAC** configured for secure access

## 📋 **Prerequisites**

- ✅ **K3s cluster** running and accessible
- ✅ **kubectl** configured with cluster access
- ✅ **Helm 3.x** installed
- ✅ **Storage class** available for persistent volumes
- ✅ **Network access** to Helm repositories

## ⚙️ **Configuration Variables**

### **Required Variables (set in group_vars/all.yml)**
```yaml
# ArgoCD Configuration
argocd_namespace: "argocd"                    # Kubernetes namespace
argocd_nodeport: 30080                        # External access port
argocd_admin_password: "your-secure-password" # Initial admin password
```

### **Optional Variables (with defaults)**
```yaml
# Helm Configuration
argocd_chart_repo: "https://argoproj.github.io/argo-helm"
argocd_chart_name: "argo-cd"
argocd_chart_version: "latest"

# Resource Allocation
argocd_server_memory_request: "256Mi"
argocd_server_memory_limit: "512Mi"
argocd_server_cpu_request: "250m"
argocd_server_cpu_limit: "500m"

# Storage
argocd_storage_size: "10Gi"
argocd_storage_class: "nfs-shared"

# Security
argocd_enable_insecure: false                 # Use HTTPS by default
argocd_enable_anonymous_access: false         # Require authentication
```

### **Advanced Configuration**
```yaml
# High-Availability Setup
argocd_ha_enabled: false                      # Enable HA mode
argocd_redis_ha_enabled: false               # Enable Redis HA

# Authentication
argocd_dex_enabled: true                      # Enable DEX for SSO
argocd_oidc_config: {}                        # OIDC configuration

# Git Repository Access
argocd_private_repos: []                      # Private repository credentials
argocd_ssh_known_hosts: []                    # SSH known hosts

# Notifications
argocd_notifications_enabled: false          # Enable notifications
argocd_slack_webhook: ""                      # Slack webhook URL
```

## 🚀 **Deployment**

### **Basic Deployment**
```bash
# Deploy ArgoCD with default configuration
ansible-playbook -i inventory/production/hosts.yml infrastructure/cluster/site.yml --tags argocd

# Deploy only ArgoCD (skip other components)
ansible-playbook -i inventory/production/hosts.yml infrastructure/cluster/site.yml --tags platform --limit argocd
```

### **Custom Configuration Deployment**
```bash
# Deploy with custom values
ansible-playbook -i inventory/production/hosts.yml infrastructure/cluster/site.yml \
  --tags argocd \
  --extra-vars "argocd_admin_password=my-secure-password argocd_nodeport=31080"
```

### **High-Availability Deployment**
```bash
# Enable HA mode for production
ansible-playbook -i inventory/production/hosts.yml infrastructure/cluster/site.yml \
  --tags argocd \
  --extra-vars "argocd_ha_enabled=true argocd_redis_ha_enabled=true"
```

## 🔐 **Access & Authentication**

### **Web UI Access**
```bash
# Access ArgoCD Web UI
URL: https://your-cluster-ip:30080
Username: admin
Password: [see password retrieval below]
```

### **Password Retrieval**
```bash
# Get the auto-generated admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d && echo

# Reset password to custom value
kubectl -n argocd patch secret argocd-secret \
  -p '{"stringData": {"admin.password": "$2a$10$rRyBsGSHK6.uc8fntPwVIuLVHgsAhAX7TcdrqW/RADU0ufHuBa3G2"}}'
# This sets password to: admin123
```

### **CLI Access**
```bash
# Install ArgoCD CLI
curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd

# Login via CLI
argocd login your-cluster-ip:30080 --username admin --password $(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
```

## 📊 **Verification & Health Checks**

### **Deployment Verification**
```bash
# Check ArgoCD pod status
kubectl get pods -n argocd

# Expected output:
# NAME                                  READY   STATUS    RESTARTS   AGE
# argocd-application-controller-xxx     1/1     Running   0          5m
# argocd-dex-server-xxx                 1/1     Running   0          5m
# argocd-redis-xxx                      1/1     Running   0          5m
# argocd-repo-server-xxx                1/1     Running   0          5m
# argocd-server-xxx                     1/1     Running   0          5m

# Check service status
kubectl get svc -n argocd

# Check ingress/nodeport access
curl -k https://your-cluster-ip:30080/api/version
```

### **Health Status**
```bash
# Check ArgoCD health via CLI
argocd cluster list
argocd app list

# Check application controller logs
kubectl logs -n argocd deployment/argocd-application-controller

# Check server logs
kubectl logs -n argocd deployment/argocd-server
```

## 🎮 **Usage Examples**

### **Deploy Your First Application**
```yaml
# Create application via YAML
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

```bash
# Apply the application
kubectl apply -f application.yaml

# Or create via CLI
argocd app create guestbook \
  --repo https://github.com/argoproj/argocd-example-apps.git \
  --path guestbook \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace default \
  --sync-policy automated
```

### **Managing Applications**
```bash
# List applications
argocd app list

# Get application details
argocd app get guestbook

# Sync application manually
argocd app sync guestbook

# Delete application
argocd app delete guestbook
```

### **Repository Management**
```bash
# Add private repository
argocd repo add https://github.com/your-org/private-repo.git \
  --username your-username \
  --password your-token

# Add SSH repository
argocd repo add git@github.com:your-org/private-repo.git \
  --ssh-private-key-path ~/.ssh/id_rsa
```

## 🔧 **Integration with MLOps Platform**

### **MLflow Integration**
```yaml
# Deploy MLflow via ArgoCD
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: mlflow
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/your-org/mlops-manifests.git
    targetRevision: HEAD
    path: mlflow
  destination:
    server: https://kubernetes.default.svc
    namespace: mlflow
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

### **Seldon Core Integration**
```yaml
# Deploy Seldon models via ArgoCD
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: model-serving
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/your-org/model-manifests.git
    targetRevision: HEAD
    path: production/models
  destination:
    server: https://kubernetes.default.svc
    namespace: seldon-system
```

## 🔒 **Security Considerations**

### **Production Security Setup**
```bash
# 1. Change default admin password
kubectl -n argocd patch secret argocd-secret \
  -p '{"stringData": {"admin.password": "your-bcrypt-hashed-password"}}'

# 2. Enable RBAC and create specific users
kubectl apply -f rbac-config.yaml

# 3. Configure TLS certificates
kubectl create secret tls argocd-server-tls \
  --cert=server.crt \
  --key=server.key \
  -n argocd

# 4. Enable network policies
kubectl apply -f network-policies.yaml
```

### **Repository Access Security**
```bash
# Use SSH keys for private repositories
kubectl create secret generic private-repo-ssh \
  --from-file=ssh-privatekey=~/.ssh/id_rsa \
  -n argocd

# Use tokens for HTTPS repositories
kubectl create secret generic private-repo-https \
  --from-literal=username=your-username \
  --from-literal=password=your-token \
  -n argocd
```

## 🐛 **Troubleshooting**

### **Common Issues**

#### **ArgoCD Server Not Starting**
```bash
# Check pod logs
kubectl logs -n argocd deployment/argocd-server

# Common causes:
# 1. Insufficient resources
# 2. Storage issues
# 3. Network policies blocking traffic

# Solutions:
kubectl describe pod -n argocd argocd-server-xxx
kubectl get events -n argocd --sort-by='.lastTimestamp'
```

#### **Application Sync Failures**
```bash
# Check application status
argocd app get your-app-name

# Check repository access
argocd repo list

# Common solutions:
# 1. Verify repository credentials
# 2. Check network connectivity
# 3. Validate YAML syntax in repository
```

#### **Authentication Issues**
```bash
# Reset admin password
kubectl -n argocd delete secret argocd-initial-admin-secret
kubectl -n argocd rollout restart deployment argocd-server

# Check DEX server logs
kubectl logs -n argocd deployment/argocd-dex-server
```

### **Performance Tuning**
```bash
# Monitor resource usage
kubectl top pods -n argocd

# Scale components for high load
kubectl scale deployment argocd-repo-server --replicas=3 -n argocd
kubectl scale deployment argocd-application-controller --replicas=2 -n argocd
```

## 📈 **Monitoring & Observability**

### **Metrics & Monitoring**
```bash
# ArgoCD exposes Prometheus metrics on:
# - argocd-application-controller: :8082/metrics
# - argocd-repo-server: :8084/metrics  
# - argocd-server: :8083/metrics

# Add ServiceMonitor for Prometheus
kubectl apply -f monitoring/service-monitor.yaml
```

### **Health Checks**
```bash
# Application health endpoint
curl -k https://your-cluster-ip:30080/api/v1/applications/your-app/health

# Cluster connectivity
argocd cluster list

# Repository connectivity  
argocd repo list
```

## 🎓 **Best Practices**

### **Application Organization**
1. **Use Projects** - Organize applications by team/environment
2. **Implement App-of-Apps** - Manage multiple applications declaratively
3. **Use Helm/Kustomize** - Leverage templating for configuration management
4. **Sync Policies** - Use automated sync for non-production, manual for production

### **GitOps Workflow**
1. **Branch Strategy** - Use branches for environment promotion
2. **Pull Requests** - Require reviews for production changes
3. **Rollback Strategy** - Maintain previous versions for quick rollback
4. **Secrets Management** - Use sealed secrets or external secret operators

### **Security Best Practices**
1. **Least Privilege** - Grant minimal required permissions
2. **Network Segmentation** - Use network policies to restrict traffic
3. **Audit Logging** - Enable audit logs for compliance
4. **Regular Updates** - Keep ArgoCD updated to latest secure version

## 🔄 **Maintenance**

### **Updates & Upgrades**
```bash
# Update ArgoCD to latest version
helm repo update
ansible-playbook -i inventory/production/hosts.yml infrastructure/cluster/site.yml --tags argocd

# Backup ArgoCD configuration
kubectl get applications -n argocd -o yaml > argocd-apps-backup.yaml
kubectl get secrets -n argocd -o yaml > argocd-secrets-backup.yaml
```

### **Backup & Recovery**
```bash
# Export applications
argocd app list -o yaml > applications-backup.yaml

# Export repositories
argocd repo list -o yaml > repositories-backup.yaml

# Restore from backup
kubectl apply -f applications-backup.yaml
```

## 🔗 **Integration Examples**

### **CI/CD Pipeline Integration**
```yaml
# GitHub Actions example
name: Deploy to ArgoCD
on:
  push:
    branches: [main]
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Update manifest
        run: |
          # Update image tag in manifest repository
          # ArgoCD will automatically sync the changes
```

### **Webhook Configuration**
```bash
# Configure webhook for automated sync
curl -X POST https://your-cluster-ip:30080/api/webhook \
  -H "Content-Type: application/json" \
  -d '{"repository": {"url": "https://github.com/your-org/your-repo.git"}}'
```

---

## 📚 **Additional Resources**

- **ArgoCD Documentation**: https://argo-cd.readthedocs.io/
- **Helm Chart**: https://github.com/argoproj/argo-helm
- **Best Practices**: https://argo-cd.readthedocs.io/en/stable/user-guide/best_practices/
- **Security**: https://argo-cd.readthedocs.io/en/stable/operator-manual/security/

## 🏆 **Platform Value**

**This ArgoCD deployment provides:**
- ✅ **Enterprise GitOps** capabilities
- ✅ **Automated deployment** pipelines  
- ✅ **Configuration drift** detection and remediation
- ✅ **Multi-environment** management
- ✅ **Audit trail** for all deployments
- ✅ **Rollback capabilities** for quick recovery
- ✅ **Integration** with existing MLOps tools

**Perfect for demonstrating modern DevOps practices and GitOps methodologies in your homelab MLOps platform!** 🚀