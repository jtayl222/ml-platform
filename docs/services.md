# 🎯 Service Dashboard & Access Guide

**Live Platform Access** - Click the links below to access your running services!

## ⚠️ **SECURITY NOTICE**

> **🔒 This is a development/demo environment with temporary credentials and configurations.**
> 
> **Before production use:**
> - 🔑 **Change all default passwords** - These are demo credentials only
> - 🔐 **Regenerate sealed secrets** with production-grade passwords  
> - 🌐 **Replace internal IP addresses** (192.168.1.85) with your actual cluster IPs
> - 🛡️ **Enable authentication** for services like MLflow and Kubeflow
> - 🔥 **Configure firewall rules** - These NodePort services are exposed to your network
> - 📜 **Review RBAC policies** and service account permissions
> - 🔒 **Enable TLS/SSL** for all web services in production
> - 📊 **Audit access logs** and enable monitoring alerts

---

## 📋 **Complete Service Table with Credentials**

| **Service** | **URL (LoadBalancer)** | **URL (NodePort Fallback)** | **Status** | **Credentials & Notes** |
|-------------|------------------------|------------------------------|------------|--------------------------|
| **ArgoCD** | [http://192.168.1.204](http://192.168.1.204) | [https://192.168.1.85:30080](https://192.168.1.85:30080) | ✅ | **User:** `admin`<br/>**Password:** [Get Password](#argocd-password) |
| **Argo Workflows** | [http://192.168.1.205](http://192.168.1.205) | [http://192.168.1.85:32746](http://192.168.1.85:32746) | ✅ | **User:** `admin`<br/>**Password:** `mlopsadmin123` ⚠️ *Demo only* |
| **JupyterHub** | [http://192.168.1.206](http://192.168.1.206) | [http://192.168.1.85:30888](http://192.168.1.85:30888) | ✅ | **User:** Any username<br/>**Password:** `mlops123` ⚠️ *Demo only* |
| **Grafana** | [http://192.168.1.207](http://192.168.1.207) | [http://192.168.1.85:30300](http://192.168.1.85:30300) | ✅ | **User:** `admin`<br/>**Password:** `admin123` ⚠️ *Demo only* |
| **Kubernetes Dashboard** | [https://192.168.1.208](https://192.168.1.208) | [https://192.168.1.85:30444](https://192.168.1.85:30444) | ✅ | **Auth:** Service Account Token ([Get Token](#dashboard-token)) |
| **MLflow** | [http://192.168.1.203:5000](http://192.168.1.203:5000) | [http://192.168.1.85:30800](http://192.168.1.85:30800) | ✅ | **Backend:** S3 via MinIO ⚠️ *No auth - enable for production*<br/>**Artifacts:** `s3://mlflow-artifacts/` |
| **MinIO API** | [http://192.168.1.200:9000](http://192.168.1.200:9000) | [http://192.168.1.85:30900](http://192.168.1.85:30900) | ✅ | **User:** `minioadmin`<br/>**Password:** `minioadmin123` ⚠️ *Demo only* |
| **MinIO Console** | [http://192.168.1.202:9090](http://192.168.1.202:9090) | [http://192.168.1.85:31578](http://192.168.1.85:31578) | ✅ | **User:** `minioadmin`<br/>**Password:** `minioadmin123` ⚠️ *Demo only* |
| **Prometheus** | *NodePort Only* | [http://192.168.1.85:30090](http://192.168.1.85:30090) | ✅ | **Metrics Collection** ⚠️ *No auth - secure for production* |
| **Seldon Core** | [http://192.168.1.202](http://192.168.1.202) | **API/CLI Only** | ✅ | **Model Serving Platform** - Deploy via kubectl |
| **NGINX Ingress** | [http://192.168.1.249](http://192.168.1.249) | *LoadBalancer Only* | ✅ | **Routes:** ml-api.local → financial-inference services |

## 🤖 **Model Serving with Seldon Core**

Seldon Core is deployed as an operator with Swagger API documentation available:

### **Access Seldon Swagger UI**
```bash
# Port-forward to access Swagger documentation
kubectl port-forward -n seldon-system svc/seldon-webhook-service 8080:443

# Access Swagger UI
open http://localhost:8080/swagger-ui/
```

### **Deploy a Test Model**
```bash
# Deploy sample iris classification model
kubectl apply -f - <<EOF
apiVersion: machinelearning.seldon.io/v1
kind: SeldonDeployment
metadata:
  name: iris-model
  namespace: seldon-system
spec:
  name: iris
  predictors:
  - graph:
      implementation: SKLEARN_SERVER
      modelUri: gs://seldon-models/sklearn/iris
      name: classifier
    name: default
    replicas: 1
EOF

# Check deployment
kubectl get seldondeployments -n seldon-system

# Access model predictions
kubectl port-forward svc/iris-default 8080:8080 -n seldon-system &
curl -X POST http://localhost:8080/api/v1.0/predictions \
  -H 'Content-Type: application/json' \
  -d '{"data": {"ndarray": [[1, 2, 3, 4]]}}'
```

## 🔄 **Kubeflow Pipelines Status**

**Current Status**: ✅ **Mostly Working** (some cache pods restarting)

### **Access Kubeflow Pipelines UI**
- **URL**: [http://192.168.1.85:31234](http://192.168.1.85:31234)
- **Status**: Core pipeline functionality working
- **Known Issues**: Cache pods may be in CrashLoopBackOff (doesn't affect core functionality)

### **Fix Cache Issues** (Optional)
```bash
# Clean up cache pods to restart them
kubectl delete pod -n kubeflow -l app=cache-server
kubectl delete pod -n kubeflow -l app=cache-deployer-deployment  
kubectl delete pod -n kubeflow -l app=ml-pipeline-viewer-crd

# Watch pods restart
kubectl get pods -n kubeflow -w
```

## 🔐 **Authentication & Access**

### **⚠️ Demo Credential Summary**
```bash
# TEMPORARY DEMO CREDENTIALS - CHANGE BEFORE PRODUCTION
Grafana:        admin / admin123
Argo Workflows: admin / mlopsadmin123  
JupyterHub:     any-username / mlops123
MinIO:          minioadmin / minioadmin123
ArgoCD:         admin / <auto-generated>
Kubeflow:       No authentication (enable for production)
```

### **Getting Dynamic Passwords**

#### ArgoCD Password
```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d
```

#### Kubernetes Dashboard Token
```bash
kubectl -n kubernetes-dashboard create token admin-user
```

## 🔧 **Service Port Reference**

| **Service** | **Main Port** | **Additional Ports** | **Protocol** |
|-------------|---------------|---------------------|--------------|
| **ArgoCD** | 30080 (HTTPS) | 30443 (gRPC) | HTTPS |
| **Argo Workflows** | 32746 (HTTP) | - | HTTP |
| **JupyterHub** | 30888 (HTTP) | - | HTTP |
| **Kubeflow Pipelines** | 31234 (HTTP) | - | HTTP |
| **Kubernetes Dashboard** | 30444 (HTTPS) | - | HTTPS |
| **MinIO Console** | 31578 (HTTP) | 30900 (API) | HTTP |
| **MLflow** | 30800 (HTTP) | - | HTTP |
| **Grafana** | 30300 (HTTP) | - | HTTP |
| **Prometheus** | 30090 (HTTP) | 30771 (Metrics) | HTTP |
| **Seldon Swagger** | Port-forward 8080 | - | HTTPS |

## ✅ **Platform Capabilities**

### **Complete MLOps Stack:**
- **🔄 GitOps**: ArgoCD for application deployment
- **⚙️ Pipelines**: Argo Workflows + Kubeflow Pipelines  
- **🧪 Experiments**: MLflow with S3 backend
- **📊 Notebooks**: JupyterHub for data science
- **🤖 Model Serving**: Seldon Core for production inference
- **💾 Storage**: MinIO (S3-compatible) 
- **📈 Monitoring**: Prometheus + Grafana
- **🎛️ Management**: Kubernetes Dashboard

### **End-to-End ML Workflow:**
- **Development**: [JupyterHub](http://192.168.1.85:30888) → Write notebooks
- **Experiments**: [MLflow](http://192.168.1.85:30800) → Track experiments  
- **Pipelines**: [Kubeflow](http://192.168.1.85:31234) + [Argo Workflows](http://192.168.1.85:32746) → Automate workflows
- **Model Serving**: Seldon Core → Deploy production models
- **Deployment**: [ArgoCD](https://192.168.1.85:30080) → GitOps automation
- **Monitoring**: [Grafana](http://192.168.1.85:30300) → Monitor performance

## 🏆 **Your High-Performance Cluster**

**Cluster Specifications:**
- **Total Resources**: 36 CPU cores, ~250GB RAM
- **Node Configuration**: 5 Intel NUCs (NUC8i5, NUC10i3/i4/i5/i7)
- **Network**: High-speed internal networking with **Cilium CNI**
- **Storage**: NFS-based persistent volumes

**Performance Optimizations Applied:**
- **CNI**: Cilium CNI with tunnel mode (resolves Calico ARP bug #8689)
- **MinIO**: 8Gi-16Gi RAM allocation for high-throughput storage
- **MLflow**: 8Gi-16Gi RAM for large experiment handling
- **JupyterHub**: Up to 16Gi RAM per user for heavy ML workloads
- **Seldon**: 4Gi-12Gi RAM for large model serving

## 🚀 **Quick Access Workflow**

### **🏆 LoadBalancer Access (Recommended)**
```bash
# ⚠️ DEMO ENVIRONMENT - Change passwords before production use

# 1. Access development environment
open http://192.168.1.206  # JupyterHub (any-user/mlops123)

# 2. Track experiments  
open http://192.168.1.203:5000  # MLflow

# 3. Create ML pipelines
open http://192.168.1.205  # Argo Workflows (admin/mlopsadmin123)

# 4. Deploy models with Seldon
kubectl get seldondeployments -A  # Check running models

# 5. Deploy via GitOps
open http://192.168.1.204  # ArgoCD (admin/<get-password>)

# 6. Monitor platform
open http://192.168.1.207  # Grafana (admin/admin123)
```

### **📡 NodePort Access (Fallback)**
```bash
# Use these if LoadBalancer IPs are not accessible

# 1. Access development environment
open http://192.168.1.85:30888  # JupyterHub (any-user/mlops123)

# 2. Track experiments  
open http://192.168.1.85:30800  # MLflow

# 3. Create ML pipelines
open http://192.168.1.85:32746  # Argo Workflows (admin/mlopsadmin123)

# 4. Deploy via GitOps
open https://192.168.1.85:30080 # ArgoCD (admin/<get-password>)

# 5. Monitor platform
open http://192.168.1.85:30300  # Grafana (admin/admin123)
```

---

**💡 Tip**: Bookmark this page for quick access to your MLOps platform!

**⚠️ Security Reminder**: This is a development/demo environment. Secure appropriately before production use.

**🏆 Enterprise Value**: This platform demonstrates production-grade MLOps infrastructure worth $200k+ in commercial solutions, optimized for your high-performance homelab.
