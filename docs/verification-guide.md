# Platform Verification & Troubleshooting Guide

## Overview

This guide provides comprehensive instructions for verifying a successful MLOps platform deployment and troubleshooting common issues, following enterprise DevOps best practices.

## 🎯 Quick Verification

### 1. Automated Health Check
```bash
# Run comprehensive platform verification
chmod +x scripts/verify-platform.sh
./scripts/verify-platform.sh

# Expected output:
# 🔍 MLOps Platform Verification Starting...
# ✅ yq v4 successfully installed
# ✅ helm: v3.15.4+gfa9efb0
# ✅ kubectl: Client Version: v1.33.1
# 🎉 Platform verification complete!
```

### 2. Ansible Test Suite
```bash
# Run comprehensive Ansible-based tests
ansible-playbook -i inventory/production/hosts-k3s infrastructure/cluster/test-platform.yml

# Expected results:
# ✅ All cluster nodes are ready
# ✅ Critical services have running pods  
# ✅ Service endpoints are accessible
# 🎯 Platform Status: HEALTHY ✅
```

## 📊 What Gets Verified

### Platform Prerequisites
- ✅ **yq v4**: Go-based YAML processor (critical for sealed secrets)
- ✅ **Helm v3**: Kubernetes package manager
- ✅ **kubectl**: Kubernetes CLI tool
- ✅ **System packages**: jq, curl, git, essential tools

### Cluster Health
- ✅ **Node readiness**: All nodes in Ready state
- ✅ **Pod status**: Running pods across all namespaces
- ✅ **Resource availability**: CPU, memory, storage capacity
- ✅ **Network connectivity**: Cross-node communication

### Core Services
- ✅ **Storage**: Persistent volumes and claims
- ✅ **MetalLB**: Load balancer functionality (if enabled)
- ✅ **Sealed Secrets**: Credential decryption working
- ✅ **CNI**: Network plugin (Cilium/Calico) operational

### Service Mesh & Observability
- ✅ **Istio**: Control plane v1.27.x running
- ✅ **Kiali**: Service mesh observability v1.85
- ✅ **Jaeger**: Distributed tracing functionality
- ✅ **Gateway**: Ingress traffic management

### MLOps Stack
- ✅ **MLflow**: Experiment tracking API accessible
- ✅ **Seldon Core**: Model serving platform ready
- ✅ **JupyterHub**: Collaborative environment running
- ✅ **Harbor**: Container registry with scanning

### DevOps Tools
- ✅ **Argo CD**: GitOps deployment system
- ✅ **Argo Workflows**: Pipeline automation
- ✅ **Monitoring**: Prometheus + Grafana stack

## 🔍 Manual Verification Commands

### Cluster Status
```bash
# Node health
kubectl get nodes -o wide
kubectl describe nodes

# Pod status across all namespaces  
kubectl get pods --all-namespaces
kubectl get pods --all-namespaces --field-selector=status.phase!=Running

# Resource usage
kubectl top nodes
kubectl top pods --all-namespaces --sort-by=cpu
```

### Service Endpoints
```bash
# LoadBalancer services
kubectl get svc --all-namespaces --field-selector spec.type=LoadBalancer

# NodePort services (fallback)
kubectl get svc --all-namespaces --field-selector spec.type=NodePort

# Ingress resources
kubectl get ingress --all-namespaces
```

### Storage Verification
```bash
# Persistent volumes
kubectl get pv,pvc --all-namespaces
kubectl describe pv

# Storage classes
kubectl get storageclass
```

### Network Testing
```bash
# DNS resolution
kubectl run test-dns --image=busybox:1.28 --restart=Never --rm -it -- nslookup kubernetes.default

# Service connectivity  
kubectl run test-connectivity --image=curlimages/curl:7.85.0 --restart=Never --rm -it -- curl -v http://mlflow-service.mlflow:5000/health
```

## 🌐 Service Access Verification

### MLflow (Experiment Tracking)
```bash
# LoadBalancer access
curl -f http://192.168.1.201:5000/health
curl -f http://192.168.1.201:5000/api/2.0/mlflow/experiments/list

# NodePort fallback
curl -f http://<control-plane-ip>:30800/health

# Expected: {"status": "OK"}
```

### Harbor (Container Registry)
```bash
# Registry health
curl -f http://192.168.1.210/api/v2.0/health

# Login test
docker login 192.168.1.210 -u admin -p <password>

# Expected: Login successful
```

### Kiali (Service Mesh Observability)
```bash
# Dashboard access
curl -f http://192.168.1.211:20001/kiali/api/status

# Expected: {"status": {"webRoot": "/kiali"}}
```

### Grafana (Monitoring)
```bash
# API health
curl -f http://192.168.1.207:3000/api/health

# Expected: {"commit": "...", "database": "ok"}
```

## 🧪 ML Workflow Testing

### Complete ML Pipeline Test
```python
import mlflow
import requests
import pandas as pd
from sklearn.ensemble import RandomForestRegressor
from sklearn.metrics import mean_squared_error
from sklearn.model_selection import train_test_split

# Set MLflow tracking URI
mlflow.set_tracking_uri("http://192.168.1.201:5000")

# Create test experiment
experiment_name = f"platform-verification-{int(time.time())}"
experiment_id = mlflow.create_experiment(experiment_name)

with mlflow.start_run(experiment_id=experiment_id):
    # Generate sample data
    from sklearn.datasets import make_regression
    X, y = make_regression(n_samples=1000, n_features=10, random_state=42)
    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2)
    
    # Train model
    model = RandomForestRegressor(n_estimators=100, random_state=42)
    model.fit(X_train, y_train)
    
    # Log metrics
    predictions = model.predict(X_test)
    mse = mean_squared_error(y_test, predictions)
    mlflow.log_metric("mse", mse)
    mlflow.log_param("n_estimators", 100)
    
    # Log model
    mlflow.sklearn.log_model(model, "model")
    
print(f"✅ ML workflow test completed successfully!")
print(f"Experiment: {experiment_name}")
print(f"MSE: {mse:.4f}")
```

## ⚠️ Common Issues & Solutions

### Prerequisites Issues

**Issue**: Sealed secrets generating empty files
```bash
# Problem: Wrong yq version (Python v3 instead of Go v4)
yq --version
# Output: yq 0.0.0 or yq version 2.x

# Solution: Run prerequisites role
ansible-playbook site.yml --tags prerequisites

# Verify fix
yq --version
# Expected: yq (https://github.com/mikefarah/yq/) version v4.44.3
```

**Issue**: Harbor webhook 301 redirect error
```bash
# Problem: Harbor forcing HTTPS for API calls
# Error: Status code was 301: HTTP Error 301: Moved Permanently

# Solution: Already fixed in harbor role (uses HTTPS with validate_certs: false)
# The webhook configuration automatically handles HTTPS redirects
```

### Cluster Health Issues

**Issue**: Nodes not ready
```bash
# Check node conditions
kubectl describe nodes | grep -A 10 "Conditions:"

# Common causes:
# - CNI not installed: Deploy Cilium/Calico
# - Disk pressure: Free up space
# - Memory pressure: Add RAM or reduce workload
```

**Issue**: Pods in Pending state
```bash
# Check resource constraints
kubectl describe pod <pod-name> -n <namespace>

# Common causes:
# - Insufficient CPU/memory: Scale cluster or reduce requests
# - Missing persistent volumes: Check storage configuration
# - Node selector issues: Verify node labels
```

### Service Mesh Issues

**Issue**: Sidecar injection not working
```bash
# Check namespace labels
kubectl get namespace <namespace> --show-labels

# Enable injection
kubectl label namespace <namespace> istio-injection=enabled

# Restart deployments
kubectl rollout restart deployment -n <namespace>
```

**Issue**: 503 Service Unavailable with Istio
```bash
# Check sidecar status
kubectl get pod <pod-name> -o yaml | grep -A 5 "istio-proxy"

# Common causes:
# - Sidecar not ready: Wait for injection
# - Network policies: Check DNS resolution to istio-system:15012
# - Certificate issues: Verify mTLS configuration
```

### Storage Issues

**Issue**: PVC stuck in Pending
```bash
# Check storage class and provisioner
kubectl get storageclass
kubectl get pvc <pvc-name> -o yaml

# For NFS issues:
# - Check NFS server accessibility
# - Verify NFS provisioner is running
# - Ensure proper mount points exist
```

### MLOps Service Issues

**Issue**: MLflow not accessible
```bash
# Check MLflow pod status
kubectl get pods -n mlflow
kubectl logs -n mlflow deployment/mlflow-server

# Check database connection
kubectl exec -n mlflow deployment/mlflow-server -- python -c "
import psycopg2
conn = psycopg2.connect(host='<postgres-ip>', database='mlflow', user='mlflow', password='<password>')
print('✅ Database connection successful')
"
```

**Issue**: Harbor registry push failures
```bash
# Check Harbor pod status
kubectl get pods -n harbor

# Test registry connectivity
docker pull hello-world
docker tag hello-world 192.168.1.210/library/hello-world:test
docker push 192.168.1.210/library/hello-world:test

# Common causes:
# - Authentication: Verify admin credentials
# - Network: Check LoadBalancer IP accessibility
# - Storage: Ensure adequate persistent volume space
```

## 📈 Performance Monitoring

### Resource Usage Baselines
```bash
# CPU and memory usage per node
kubectl top nodes

# Pod resource consumption
kubectl top pods --all-namespaces --sort-by=cpu
kubectl top pods --all-namespaces --sort-by=memory

# Storage usage
df -h /var/lib/rancher/k3s  # K3s data directory
kubectl get pv -o custom-columns=NAME:.metadata.name,CAPACITY:.spec.capacity.storage,USED:.status.phase
```

### Service Response Times
```bash
# MLflow API response time
time curl -f http://192.168.1.201:5000/api/2.0/mlflow/experiments/list

# Harbor API response time  
time curl -f http://192.168.1.210/api/v2.0/health

# Grafana dashboard response time
time curl -f http://192.168.1.207:3000/api/health
```

## 🚨 Alerts & Monitoring

### Critical Metrics to Monitor

1. **Node Health**: CPU > 80%, Memory > 85%, Disk > 90%
2. **Pod Crashes**: Restart count > 5 in 1 hour
3. **Service Availability**: HTTP response > 5s or 5xx errors
4. **Storage**: PVC usage > 85%
5. **Network**: Packet loss > 1%

### Grafana Dashboards

Key dashboards to monitor:
- **Kubernetes Cluster**: Node and pod metrics
- **Istio Service Mesh**: Traffic and performance
- **MLflow Metrics**: Experiment and model tracking
- **Harbor Registry**: Image scan and storage metrics

## 🔧 Maintenance Commands

### Regular Health Checks
```bash
# Daily cluster health
kubectl get nodes,pods --all-namespaces | grep -v Running

# Weekly resource cleanup
kubectl delete pods --field-selector=status.phase=Succeeded --all-namespaces
kubectl delete pods --field-selector=status.phase=Failed --all-namespaces

# Monthly storage review
kubectl get pv -o custom-columns=NAME:.metadata.name,CAPACITY:.spec.capacity.storage,STATUS:.status.phase
```

### Log Collection
```bash
# Collect logs for troubleshooting
kubectl logs -n istio-system deployment/istiod > istio-logs.txt
kubectl logs -n mlflow deployment/mlflow-server > mlflow-logs.txt
kubectl logs -n harbor deployment/harbor-core > harbor-logs.txt

# System events
kubectl get events --sort-by=.metadata.creationTimestamp --all-namespaces
```

## 📞 Support & Documentation

### Additional Resources
- [Kubernetes Troubleshooting](https://kubernetes.io/docs/tasks/debug-application-cluster/)
- [Istio Troubleshooting](https://istio.io/latest/docs/ops/troubleshooting/)
- [MLflow Documentation](https://mlflow.org/docs/latest/index.html)
- [Harbor User Guide](https://goharbor.io/docs/latest/)

### Platform-Specific Docs
- [`docs/architecture.md`](architecture.md) - Platform design and components
- [`docs/services.md`](services.md) - Service access and configuration
- [`infrastructure/cluster/roles/`](../infrastructure/cluster/roles/) - Role-specific documentation

---

**Remember**: Always run the verification scripts after deployment to ensure a healthy platform state! 🎯