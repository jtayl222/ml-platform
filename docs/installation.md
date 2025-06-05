# 🏗️ Installation Guide

Complete setup guide for the K3s MLOps Platform.

## 📋 **Prerequisites**

### **Infrastructure Requirements**
- **Control Plane**: 1 node, 4GB RAM, 2 CPU cores, 40GB storage
- **Worker Nodes**: 1+ nodes, 8GB RAM, 4 CPU cores, 100GB storage  
- **Operating System**: Ubuntu 20.04+ or Debian 11+
- **Network**: All nodes on same subnet with SSH access

### **Local Development Machine**
```bash
# Required tools
sudo apt update
sudo apt install -y ansible git curl

# Verify Ansible version (2.12+ required)
ansible --version
```

## 🚀 **Quick Installation**

### **1. Clone Repository**
```bash
git clone https://github.com/yourusername/k3s-homelab.git
cd k3s-homelab
```

### **2. Configure Inventory**
```bash
# Copy example inventory
cp inventory/production/hosts.yml.example inventory/production/hosts.yml

# Edit with your node IPs
nano inventory/production/hosts.yml
```

Example inventory:
```yaml
all:
  children:
    k3s_cluster:
      hosts:
        master-node:
          ansible_host: 192.168.1.85
          node_role: control-plane
        worker-node-1:
          ansible_host: 192.168.1.104
          node_role: worker
```

### **3. Generate Sealed Secrets**
```bash
# Create all platform secrets
./scripts/create-all-sealed-secrets.sh
```

### **4. Deploy Platform**
```bash
# Full platform deployment (30-45 minutes)
ansible-playbook -i inventory/production/hosts infrastructure/cluster/site.yml

# Monitor deployment progress
kubectl get pods --all-namespaces -w
```

### **5. Verify Installation**
```bash
# Check all services are running
kubectl get svc --all-namespaces | grep NodePort

# Access service dashboard
echo "Service Dashboard: See docs/services.md"
```

## 🔧 **Detailed Configuration**

### **Network Configuration**
```yaml
# inventory/production/group_vars/all.yml
k3s_cluster_cidr: "10.42.0.0/16"
k3s_service_cidr: "10.43.0.0/16"
k3s_cluster_dns: "10.43.0.10"
```

### **Storage Configuration**
```yaml
# Configure persistent storage
storage_class: "local-path"  # Default K3s storage
nfs_server: "192.168.1.100"  # Optional NFS server
```

### **Security Configuration**
```yaml
# Enable additional security features
enable_network_policies: false  # Set to true for production
enable_pod_security: true
enable_rbac: true
```

## 🐛 **Troubleshooting Installation**

### **Common Issues**

#### **SSH Connection Failed**
```bash
# Test SSH connectivity
ansible all -i inventory/production/hosts -m ping

# Fix SSH issues
ssh-copy-id user@192.168.1.85
```

#### **K3s Installation Failed**
```bash
# Check K3s service status
ssh user@192.168.1.85 "sudo systemctl status k3s"

# Restart K3s if needed
ssh user@192.168.1.85 "sudo systemctl restart k3s"
```

#### **Pods Not Starting**
```bash
# Check pod status
kubectl get pods --all-namespaces

# Check node resources
kubectl top nodes

# Describe failed pods
kubectl describe pod <pod-name> -n <namespace>
```

#### **NodePort Services Not Accessible**
```bash
# Check firewall rules
sudo ufw status

# Add required ports
sudo ufw allow 30000:32767/tcp
```

### **Component-Specific Installation**

#### **MLflow Only**
```bash
ansible-playbook -i inventory/production/hosts infrastructure/cluster/site.yml --tags=mlflow
```

#### **Monitoring Stack Only**
```bash
ansible-playbook -i inventory/production/hosts infrastructure/cluster/site.yml --tags=monitoring
```

#### **Skip Kubeflow**
```bash
ansible-playbook -i inventory/production/hosts infrastructure/cluster/site.yml --skip-tags=kubeflow
```

## 📈 **Post-Installation**

### **1. Verify All Services**
Visit [Service Dashboard](services.md) and test each service.

### **2. Configure Monitoring**
```bash
# Import Grafana dashboards
# Access Grafana at http://your-ip:30300 (admin/admin123)
# Import dashboard ID: 11074 (Node Exporter Full)
```

### **3. Set Up ML Pipeline**
See [MLOps Workflow Guide](mlops-workflow.md) for creating your first ML pipeline.

### **4. Configure GitOps**
See [ArgoCD Guide](services/argocd.md) for setting up application deployments.

## 🔄 **Updating the Platform**

### **Update All Components**
```bash
ansible-playbook -i inventory/production/hosts infrastructure/cluster/site.yml --tags=update
```

### **Update Specific Component**
```bash
# Update MLflow
ansible-playbook -i inventory/production/hosts infrastructure/cluster/site.yml --tags=mlflow

# Update monitoring
ansible-playbook -i inventory/production/hosts infrastructure/cluster/site.yml --tags=monitoring
```

## 📊 **Installation Validation**

### **Health Check Script**
```bash
#!/bin/bash
echo "🔍 MLOps Platform Health Check"

# Check K3s cluster
kubectl get nodes
kubectl get pods --all-namespaces | grep -v Running | grep -v Completed

# Test service endpoints
services=("30800" "30080" "32746" "30888" "30300" "30090")
for port in "${services[@]}"; do
    if curl -s http://192.168.1.85:$port > /dev/null; then
        echo "✅ Port $port: OK"
    else
        echo "❌ Port $port: Failed"
    fi
done
```

---

## 🆘 **Getting Help**

- **Issues**: Create GitHub issue with logs and configuration
- **Discussions**: Join project discussions for questions
- **Documentation**: Check [troubleshooting guide](troubleshooting.md)

**⚡ Total Installation Time: 30-45 minutes on modern hardware**
