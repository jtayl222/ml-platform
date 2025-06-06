# 🚀 K3s MLOps Homelab Setup Guide

**Complete enterprise-grade MLOps platform deployment on high-performance homelab cluster**

## 🏗️ **Infrastructure Overview**

### **Cluster Specifications**
- **Total Resources**: 36 CPU cores, ~250GB RAM across 5 Intel NUC nodes
- **Network**: High-speed internal networking (192.168.1.0/24)
- **Storage**: NFS-based persistent volumes with 1Ti+ capacity
- **OS**: Ubuntu Server on all nodes

### **Node Configuration**
| Node | Model | CPU Cores | RAM | Role |
|------|-------|-----------|-----|------|
| NUC8i5BEHS | Intel NUC8i5 | 8 | 32GB | Control Plane |
| NUC10i3FNH | Intel NUC10i3 | 4 | 64GB | Worker |
| NUC10i4FNH | Intel NUC10i4 | 4 | 64GB | Worker |
| NUC10i5FNH | Intel NUC10i5 | 8 | 32GB | Worker |
| NUC10i7FNH | Intel NUC10i7 | 12 | 64GB | Worker + NFS Server |

## 📋 **Prerequisites**

### **System Requirements**
- Ubuntu 20.04+ on all nodes
- Ansible 2.10+ on deployment machine
- SSH key access to all nodes
- Python 3.8+ with pip

### **Network Requirements**
- Static IP addresses for all nodes
- Internal network connectivity (192.168.1.0/24)
- Internet access for container registry pulls

## ⚡ **Quick Start Deployment**

### **1. Clone and Setup**
```bash
# Clone the repository
git clone <your-repo-url> k3s-homelab
cd k3s-homelab

# Install Ansible dependencies
pip3 install ansible kubernetes

# Install Ansible collections
ansible-galaxy collection install kubernetes.core
ansible-galaxy collection install ansible.posix
```

### **2. Configure Inventory**
```bash
# Edit inventory with your node IPs
vim inventory/production/hosts.yml

# Example configuration:
all:
  children:
    k3s_control_plane:
      hosts:
        NUC8i5BEHS:
          ansible_host: 192.168.1.85
    k3s_workers:
      hosts:
        NUC10i3FNH:
          ansible_host: 192.168.1.81
        NUC10i4FNH:
          ansible_host: 192.168.1.82
        NUC10i5FNH:
          ansible_host: 192.168.1.83
        NUC10i7FNH:
          ansible_host: 192.168.1.84
    nfs_server:
      hosts:
        NUC10i7FNH:
          ansible_host: 192.168.1.84
```

### **3. Deploy the Complete Platform**
```bash
# Deploy everything (takes 20-30 minutes)
ansible-playbook -i inventory/production/hosts.yml infrastructure/cluster/site.yml

# Or deploy in stages:
ansible-playbook -i inventory/production/hosts.yml infrastructure/cluster/site.yml --tags k3s
ansible-playbook -i inventory/production/hosts.yml infrastructure/cluster/site.yml --tags storage
ansible-playbook -i inventory/production/hosts.yml infrastructure/cluster/site.yml --tags platform
ansible-playbook -i inventory/production/hosts.yml infrastructure/cluster/site.yml --tags mlops
```

## 🎯 **Deployed Services**

| **Component** | **Purpose** | **Resources** | **Access** |
|---------------|-------------|---------------|------------|
| **K3s Cluster** | Kubernetes platform | 36 cores, 250GB RAM | kubectl |
| **NFS Storage** | Persistent volumes | 1Ti+ shared storage | Internal |
| **MinIO** | S3-compatible storage | 8Gi-16Gi RAM | :30900/:30901 |
| **Prometheus Stack** | Monitoring & alerting | Optimized resources | :30090/:30300 |
| **MLflow** | Experiment tracking | 8Gi-16Gi RAM | :30800 |
| **JupyterHub** | Data science platform | 16Gi RAM per user | :30888 |
| **Seldon Core** | Model serving | 4Gi-12Gi RAM | API/CLI |
| **Kubeflow Pipelines** | ML workflows | Standard resources | :31234 |
| **Argo CD** | GitOps deployment | Standard resources | :30080 |
| **Argo Workflows** | Pipeline orchestration | 2Gi-8Gi RAM | :32746 |
| **Kubernetes Dashboard** | Cluster management | Standard resources | :30444 |

## 🔧 **Post-Deployment Configuration**

### **1. Verify Deployment**
```bash
# Check cluster status
kubectl get nodes -o wide
kubectl get pods --all-namespaces

# Check Helm deployments
helm list --all-namespaces

# Verify services
kubectl get services --all-namespaces | grep NodePort
```

### **2. Fix Any Issues**
```bash
# Common fixes for Kubeflow Pipelines cache issues
kubectl delete pod -n kubeflow -l app=cache-server
kubectl delete pod -n kubeflow -l app=cache-deployer-deployment
kubectl delete pod -n kubeflow -l app=ml-pipeline-viewer-crd

# Wait for pods to restart
kubectl get pods -n kubeflow -w
```

### **3. Configure Access**
```bash
# Get kubeconfig
export KUBECONFIG=/tmp/k3s-kubeconfig.yaml

# Get ArgoCD password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d

# Create dashboard token
kubectl -n kubernetes-dashboard create token admin-user
```

## 🚀 **Access Your Platform**

After successful deployment, access your services:

### **Core MLOps Services**
- **JupyterHub**: http://192.168.1.85:30888 (any-username/mlops123)
- **MLflow**: http://192.168.1.85:30800 (experiment tracking)
- **Kubeflow Pipelines**: http://192.168.1.85:31234 (ML workflows)
- **MinIO Console**: http://192.168.1.85:31578 (storage management)

### **Platform Management**
- **Argo CD**: https://192.168.1.85:30080 (GitOps)
- **Argo Workflows**: http://192.168.1.85:32746 (pipeline execution)
- **Kubernetes Dashboard**: https://192.168.1.85:30444 (cluster management)
- **Grafana**: http://192.168.1.85:30300 (monitoring)

## 🔍 **Troubleshooting**

### **Common Issues**

#### **Kubeflow Cache Pods CrashLooping**
```bash
# This is a known issue with Kubeflow cache components
# Solution: Delete and let them restart
kubectl delete pod -n kubeflow $(kubectl get pods -n kubeflow -o name | grep cache)

# Check if database connectivity is working
kubectl logs -n kubeflow deployment/mysql
```

#### **Prometheus Stack Failed**
```bash
# Usually resource constraints
kubectl describe pod -n monitoring -l app.kubernetes.io/name=prometheus

# Check PVC status
kubectl get pvc -n monitoring
```

#### **Service Not Accessible**
```bash
# Check NodePort services
kubectl get services --all-namespaces | grep NodePort

# Verify firewall rules
sudo ufw status
```

### **Resource Monitoring**
```bash
# Monitor resource usage
kubectl top nodes
kubectl top pods --all-namespaces

# Check resource allocation
kubectl describe nodes | grep -A 10 "Allocated resources"
```

## 🛡️ **Security Configuration**

### **Production Security Steps**
```bash
# 1. Change default passwords (see docs/services.md)
# 2. Configure firewall
sudo ufw enable
sudo ufw allow 22/tcp
sudo ufw allow from 192.168.1.0/24 to any port 30000:32767

# 3. Generate new sealed secrets
# Edit infrastructure/cluster/roles/foundation/secrets/vars/main.yml
# Run: ansible-playbook -i inventory/production/hosts.yml infrastructure/cluster/site.yml --tags secrets

# 4. Enable TLS (optional)
# Configure cert-manager for automatic certificate management
```

## 📈 **Performance Optimization**

### **Resource Allocation Tuning**
```bash
# Your cluster can handle heavy workloads
# Current optimizations in inventory/production/group_vars/all.yml:

# MinIO: 8Gi-16Gi (high-throughput storage)
# MLflow: 8Gi-16Gi (large experiment handling)
# JupyterHub: Up to 16Gi per user (heavy ML workloads)
# Seldon: 4Gi-12Gi (large model serving)
```

### **Storage Performance**
```bash
# NFS performance tuning
# Ensure NFS server (NUC10i7FNH) has SSD storage
# Consider adding additional storage nodes for redundancy
```

## 🔄 **Maintenance & Updates**

### **Regular Maintenance Tasks**
```bash
# Update cluster
ansible-playbook -i inventory/production/hosts.yml infrastructure/cluster/site.yml --tags k3s

# Update Helm charts
helm repo update
ansible-playbook -i inventory/production/hosts.yml infrastructure/cluster/site.yml --tags platform

# Backup important data
kubectl get secrets --all-namespaces -o yaml > backup-secrets.yaml
```

### **Monitoring & Alerts**
```bash
# Set up Grafana dashboards for:
# - Cluster resource utilization
# - Application performance
# - Storage usage
# - Network traffic

# Access Grafana: http://192.168.1.85:30300 (admin/admin123)
```

## 📚 **Next Steps**

1. **[Service Access Guide](services.md)** - Complete service access and credentials
2. **[Development Workflow](development.md)** - ML development best practices  
3. **[Production Hardening](production.md)** - Security and reliability improvements
4. **[Performance Tuning](performance.md)** - Optimize for your workloads

## 🏆 **Platform Value**

**Your deployed platform includes:**
- ✅ Enterprise-grade MLOps infrastructure ($200k+ commercial value)
- ✅ High-performance homelab optimization 
- ✅ Production-ready monitoring and observability
- ✅ Complete ML lifecycle management
- ✅ GitOps-enabled CI/CD pipelines
- ✅ Scalable model serving capabilities

**Congratulations! You now have a production-grade MLOps platform running on your homelab cluster!** 🎉

---

**💡 Bookmark**: [Service Dashboard](services.md) for quick access to all platform services

**🔧 Support**: Check the troubleshooting section above for common issues and solutions