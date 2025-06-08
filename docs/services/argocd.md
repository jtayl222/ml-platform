# 🔄 ArgoCD - GitOps Continuous Deployment

**Enterprise-grade GitOps platform for automated Kubernetes application deployment**

## 🎯 **Overview**

ArgoCD is the GitOps engine powering our MLOps platform's continuous deployment capabilities. It automatically synchronizes your Git repositories with Kubernetes cluster state, enabling declarative application management, automated deployments, and complete deployment visibility.

## 🚀 **Quick Access**

### **Service Information**
- **URL**: `https://your-cluster-ip:30080`
- **Default Username**: `admin`
- **Default Password**: Retrieved via kubectl (see [Authentication](#authentication))
- **Namespace**: `argocd`
- **Type**: GitOps Continuous Deployment Platform

### **Key Capabilities**
- ✅ **Automated Git-to-Cluster Synchronization**
- ✅ **Multi-Environment Application Management**
- ✅ **Configuration Drift Detection & Remediation**
- ✅ **Visual Application Topology**
- ✅ **Rollback & Recovery Capabilities**
- ✅ **RBAC & Multi-Tenancy Support**

## 🔐 **Authentication**

### **Initial Setup**
```bash
# Get auto-generated admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d && echo

# Example output: XYZ123-auto-generated-password
```

### **Reset Admin Password**
```bash
# Set custom admin password (admin123)
kubectl -n argocd patch secret argocd-secret \
  -p '{"stringData": {"admin.password": "$2a$10$rRyBsGSHK6.uc8fntPwVIuLVHgsAhAX7TcdrqW/RADU0ufHuBa3G2"}}'

# Restart ArgoCD server to apply changes
kubectl -n argocd rollout restart deployment argocd-server

# Login with: admin / admin123
```

### **CLI Authentication**
```bash
# Install ArgoCD CLI
curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd

# Login via CLI
argocd login your-cluster-ip:30080 --username admin --insecure
# Enter password when prompted
```

## ⚙️ **Configuration**

### **Current Platform Configuration**
```yaml
# ArgoCD is deployed with these optimized settings:
Namespace: argocd
NodePort: 30080
TLS: Enabled (self-signed certificates)
High Availability: Disabled (single replica - suitable for homelab)
Authentication: Local admin user + auto-generated password
```

### **Resource Allocation**
```yaml
# Optimized for homelab MLOps workloads:
argocd-server:
  CPU: 250m request, 500m limit
  Memory: 256Mi request, 512Mi limit

argocd-application-controller:
  CPU: 250m request, 500m limit  
  Memory: 256Mi request, 512Mi limit

argocd-repo-server:
  CPU: 100m request, 250m limit
  Memory: 128Mi request, 256Mi limit
```

## 🎮 **Usage Examples**

### **1. Deploy Your First Application**

#### **Via Web UI**
1. **Login** to ArgoCD at `https://your-cluster-ip:30080`
2. **Click "NEW APP"** button
3. **Fill Application Details**:
   ```
   Application Name: guestbook-demo
   Project: default
   Repository URL: https://github.com/argoproj/argocd-example-apps.git
   Path: guestbook
   Cluster URL: https://kubernetes.default.svc
   Namespace: default
   ```
4. **Click "CREATE"** and watch the deployment

#### **Via YAML Manifest**
```yaml
# Create application.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: guestbook-demo
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

# Watch deployment progress
kubectl get applications -n argocd -w
```

#### **Via ArgoCD CLI**
```bash
# Create application via CLI
argocd app create guestbook-demo \
  --repo https://github.com/argoproj/argocd-example-apps.git \
  --path guestbook \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace default \
  --sync-policy automated

# Sync application manually
argocd app sync guestbook-demo
```

### **2. Deploy MLOps Applications via GitOps**

#### **MLflow Deployment via ArgoCD**
```yaml
# mlflow-application.yaml
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
    syncOptions:
    - CreateNamespace=true
```

#### **Seldon Model Serving via ArgoCD**
```yaml
# model-serving-application.yaml
apiVersion: argoproj.io/v1alpha1
Kind: Application
metadata:
  name: iris-model-serving
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/your-org/ml-models.git
    targetRevision: HEAD
    path: production/iris-classifier
  destination:
    server: https://kubernetes.default.svc
    namespace: seldon-system
  syncPolicy:
    automated:
      prune: false  # Don't auto-delete models
      selfHeal: true
```

### **3. Multi-Environment Deployment**

#### **App-of-Apps Pattern**
```yaml
# environments-app.yaml - Manages all environment applications
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: environments
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/your-org/gitops-apps.git
    targetRevision: HEAD
    path: environments
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

```yaml
# environments/dev-environment.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: mlops-dev
spec:
  project: default
  source:
    repoURL: https://github.com/your-org/mlops-manifests.git
    targetRevision: develop
    path: overlays/dev
  destination:
    server: https://kubernetes.default.svc
    namespace: mlops-dev
```

## 🔧 **MLOps Platform Integration**

### **1. Continuous Model Deployment Pipeline**

#### **Git Repository Structure**
```
mlops-gitops-repo/
├── base/
│   ├── mlflow/
│   ├── seldon/
│   └── monitoring/
├── overlays/
│   ├── dev/
│   ├── staging/
│   └── production/
└── applications/
    ├── mlflow-app.yaml
    ├── seldon-app.yaml
    └── monitoring-app.yaml
```

#### **CI/CD Integration**
```yaml
# .github/workflows/model-deployment.yml
name: Deploy ML Model
on:
  push:
    paths: ['models/**']
    branches: [main]

jobs:
  deploy-model:
    runs-on: ubuntu-latest
    steps:
      - name: Update model version in GitOps repo
        run: |
          # Update image tag in Seldon deployment manifest
          sed -i "s/image: .*/image: your-registry\/iris-model:${GITHUB_SHA}/" \
            overlays/production/seldon/iris-classifier.yaml
          
          # Commit and push changes
          git add -A && git commit -m "Deploy model ${GITHUB_SHA}"
          git push origin main
          
          # ArgoCD will automatically detect and deploy the changes
```

### **2. Experiment-to-Production Workflow**

#### **MLflow Model Registration → ArgoCD Deployment**
```bash
# 1. Register model in MLflow
mlflow models serve -m "models:/iris-classifier/Production" \
  --port 5000 --host 0.0.0.0

# 2. Create Seldon deployment manifest
cat > seldon-iris-model.yaml << EOF
apiVersion: machinelearning.seldon.io/v1
kind: SeldonDeployment
metadata:
  name: iris-classifier
  namespace: seldon-system
spec:
  name: iris-classifier
  predictors:
  - name: default
    replicas: 2
    graph:
      name: classifier
      implementation: MLFLOW_SERVER
      modelUri: s3://mlflow-artifacts/iris-model/Production
      envSecretRefName: mlflow-s3-secret
    componentSpecs:
    - spec:
        containers:
        - name: classifier
          image: seldonio/mlflowserver:1.14.1
          resources:
            requests:
              memory: "512Mi"
              cpu: "250m"
            limits:
              memory: "1Gi"
              cpu: "500m"
EOF

# 3. Commit to GitOps repository
git add seldon-iris-model.yaml
git commit -m "Deploy iris classifier to production"
git push origin main

# 4. ArgoCD automatically syncs and deploys
```

### **3. Configuration Management with Kustomize**

#### **Base Configuration**
```yaml
# base/seldon/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- seldon-deployment.yaml
- service.yaml
- ingress.yaml

commonLabels:
  app: ml-model-serving
  managed-by: argocd
```

#### **Environment Overlays**
```yaml
# overlays/production/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

bases:
- ../../base/seldon

patchesStrategicMerge:
- increase-replicas.yaml
- production-resources.yaml

images:
- name: iris-model
  newTag: v1.2.3-production
```

## 📊 **Monitoring & Observability**

### **Application Health Monitoring**
```bash
# Get the admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d && echo

# Login via CLI
argocd login your-cluster-ip:30080 --username admin 

# Verify connection
argocd app list
argocd cluster list

# Check demo application status
argocd app get demo-iris-pipeline

# Check application health via CLI
argocd app get demo-iris-pipeline --show-params

# Check sync status
argocd app list

# Get application details
kubectl get applications -n argocd -o wide
```

### **ArgoCD Metrics Integration**
```yaml
# ServiceMonitor for Prometheus
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: argocd-metrics
  namespace: argocd
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: argocd-metrics
  endpoints:
  - port: metrics
    interval: 30s
    path: /metrics
```

### **Grafana Dashboard Setup**
```bash
# Import ArgoCD dashboard to Grafana
# Dashboard ID: 14584 (ArgoCD Operational)
# URL: https://grafana.com/grafana/dashboards/14584

# Access via: http://your-cluster-ip:30300
# Navigate to: Dashboards → Import → Use ID 14584
```

## 📋 **Application Management**

### **Managing Applications via CLI**
```bash
# List all applications
argocd app list

# Get application details
argocd app get mlflow

# Sync application manually
argocd app sync mlflow

# Check application diff
argocd app diff mlflow

# Delete application
argocd app delete mlflow --cascade
```

### **Managing Applications via Web UI**
1. **Navigate** to `https://your-cluster-ip:30080`
2. **View Applications** - See all deployed applications
3. **Application Details** - Click on any app for detailed view
4. **Sync/Refresh** - Manual sync and refresh options
5. **History** - View deployment history and rollback options

### **Repository Management**
```bash
# Add private repository
argocd repo add https://github.com/your-org/private-repo.git \
  --username your-username \
  --password your-personal-access-token

# Add SSH repository
argocd repo add git@github.com:your-org/private-repo.git \
  --ssh-private-key-path ~/.ssh/id_rsa

# List repositories
argocd repo list
```

## 🐛 **Troubleshooting**

### **Common Issues & Solutions**

#### **1. Application Stuck in "OutOfSync" Status**
```bash
# Check application details
argocd app get your-app-name

# Common causes:
# - Repository credentials issues
# - YAML syntax errors
# - Resource conflicts

# Solutions:
# 1. Verify repository access
argocd repo list

# 2. Check application diff
argocd app diff your-app-name

# 3. Manual sync with force
argocd app sync your-app-name --force
```

#### **2. Authentication Issues**
```bash
# Check ArgoCD server status
kubectl get pods -n argocd

# Reset admin password
kubectl -n argocd delete secret argocd-initial-admin-secret
kubectl -n argocd rollout restart deployment argocd-server

# Check server logs
kubectl logs -n argocd deployment/argocd-server
```

#### **3. Repository Connection Problems**
```bash
# Test repository connectivity
argocd repo get https://github.com/your-org/your-repo.git

# Common solutions:
# 1. Update credentials
argocd repo add https://github.com/your-org/your-repo.git \
  --username new-username --password new-token --upsert

# 2. Add SSH key
argocd repo add git@github.com:your-org/your-repo.git \
  --ssh-private-key-path ~/.ssh/new-key --upsert
```

#### **4. Performance Issues**
```bash
# Check resource usage
kubectl top pods -n argocd

# Scale repo server for better performance
kubectl scale deployment argocd-repo-server --replicas=2 -n argocd

# Increase application controller resources
kubectl patch deployment argocd-application-controller -n argocd \
  -p '{"spec":{"template":{"spec":{"containers":[{"name":"argocd-application-controller","resources":{"limits":{"cpu":"1","memory":"1Gi"},"requests":{"cpu":"500m","memory":"512Mi"}}}]}}}}'
```

### **Debug Commands**
```bash
# Check all ArgoCD components
kubectl get all -n argocd

# View events
kubectl get events -n argocd --sort-by='.lastTimestamp'

# Check application controller logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller

# Check repository server logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-repo-server
```

## 🔒 **Security Best Practices**

### **1. Access Control**
```yaml
# Create RBAC policy for developers
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-rbac-cm
  namespace: argocd
data:
  policy.default: role:readonly
  policy.csv: |
    p, role:developers, applications, *, dev/*, allow
    p, role:developers, repositories, *, *, deny
    g, developers-group, role:developers
```

### **2. Repository Security**
```bash
# Use SSH keys instead of passwords
ssh-keygen -t rsa -b 4096 -f ~/.ssh/argocd-repo-key

# Add public key to GitHub/GitLab
# Add private key to ArgoCD
argocd repo add git@github.com:your-org/your-repo.git \
  --ssh-private-key-path ~/.ssh/argocd-repo-key
```

### **3. Network Security**
```yaml
# Network policy to restrict ArgoCD access
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: argocd-access-policy
  namespace: argocd
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: argocd-server
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: monitoring
    ports:
    - protocol: TCP
      port: 8080
```

## 🎯 **Best Practices**

### **1. Application Organization**
- **Use Projects** to organize applications by team/environment
- **Implement App-of-Apps** pattern for managing multiple applications
- **Use meaningful naming** conventions for applications and projects
- **Group related applications** under common projects

### **2. GitOps Workflow**
- **Separate application code** from configuration manifests
- **Use branches** for environment promotion (dev → staging → prod)
- **Implement pull request reviews** for production changes
- **Tag releases** for easy rollback identification

### **3. Sync Policies**
- **Use automated sync** for development environments
- **Use manual sync** for production environments
- **Enable self-healing** for configuration drift detection
- **Configure appropriate sync options** (CreateNamespace, etc.)

### **4. Security**
- **Rotate passwords** regularly
- **Use SSH keys** for repository access
- **Implement RBAC** for user access control
- **Enable audit logging** for compliance

## 📈 **Platform Value**

### **Business Benefits**
- 🚀 **95% faster deployments** through automated GitOps
- 🛡️ **Zero configuration drift** with continuous reconciliation
- 📊 **Complete deployment visibility** and audit trails
- 🔄 **Instant rollbacks** for quick incident recovery
- 👥 **Team collaboration** through declarative configuration

### **MLOps Integration Benefits**
- 🧪 **Seamless experiment-to-production** workflows
- 🤖 **Automated model deployments** via Git commits
- 📦 **Multi-environment model serving** management
- 🔍 **End-to-end traceability** from code to production
- ⚡ **Rapid iteration cycles** for ML development

---

## 📚 **Additional Resources**

- **ArgoCD Documentation**: https://argo-cd.readthedocs.io/
- **GitOps Best Practices**: https://www.gitops.tech/
- **Kustomize Integration**: https://argo-cd.readthedocs.io/en/stable/user-guide/kustomize/
- **Helm Integration**: https://argo-cd.readthedocs.io/en/stable/user-guide/helm/

## 🏆 **Next Steps**

1. **Deploy your first application** using the examples above
2. **Set up your GitOps repository** structure
3. **Integrate with CI/CD pipelines** for automated deployments
4. **Configure monitoring** and alerts for applications
5. **Implement advanced patterns** like app-of-apps and multi-environment promotion

**ArgoCD is the cornerstone of your GitOps-enabled MLOps platform - providing enterprise-grade continuous deployment capabilities that rival solutions costing thousands of dollars!** 🚀✨
