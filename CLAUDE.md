# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a production-ready MLOps platform built on K3s (lightweight Kubernetes) with infrastructure automation via Ansible. The platform provides end-to-end ML lifecycle management including experiment tracking, model serving, pipeline orchestration, and comprehensive monitoring.

## Architecture

### Infrastructure Layer
- **K3s Cluster**: 1 control plane + 4 worker nodes (36 CPU cores, 250GB RAM total)
- **Storage**: MinIO (S3-compatible) + NFS + Local storage
- **Security**: Sealed Secrets for GitOps-safe credential management
- **Service Mesh**: Istio (optional, for KServe)
- **Load Balancer**: MetalLB for bare-metal LoadBalancer services

### MLOps Stack
- **MLflow**: Experiment tracking and model registry (PostgreSQL backend)
- **Seldon Core**: Production model serving
- **KServe**: Kubernetes-native model serving (requires Istio)
- **JupyterHub**: Collaborative data science environment
- **Kubeflow Pipelines**: ML workflow orchestration

### DevOps Layer
- **Argo CD**: GitOps continuous deployment
- **Argo Workflows**: Pipeline automation and CI/CD
- **Argo Events**: Event-driven workflows
- **Prometheus + Grafana**: Comprehensive monitoring and observability

## Key Commands

### Infrastructure Deployment
```bash
# Deploy complete platform (20-30 minutes)
ansible-playbook -i inventory/production/hosts infrastructure/cluster/site.yml

# Deploy specific components
ansible-playbook -i inventory/production/hosts infrastructure/cluster/site.yml --tags k3s
ansible-playbook -i inventory/production/hosts infrastructure/cluster/site.yml --tags mlops
ansible-playbook -i inventory/production/hosts infrastructure/cluster/site.yml --tags monitoring
ansible-playbook -i inventory/production/hosts infrastructure/cluster/site.yml --tags metallb

# Deploy with MetalLB enabled (enables LoadBalancer services)
ansible-playbook -i inventory/production/hosts infrastructure/cluster/site.yml -e metallb_state=present

# Teardown cluster
ansible-playbook -i inventory/production/hosts infrastructure/cluster/site.yml -e k3s_state=absent
```

### Secret Management
```bash
# Create all required sealed secrets
./scripts/create-all-sealed-secrets.sh

# Create individual sealed secret
./scripts/create-sealed-secret.sh <secret-name> <namespace> key1=value1 key2=value2

# Generate ML project secrets
./scripts/generate-ml-secrets.sh <project-name> <email>
```

### Cluster Management
```bash
# Access cluster
export KUBECONFIG=/tmp/k3s-kubeconfig.yaml
kubectl get nodes

# Quick cluster health check
kubectl get pods --all-namespaces
kubectl wait --for=condition=Ready nodes --all --timeout=300s
```

### Platform Services Access
- **MLflow**: `http://<cluster-ip>:30800`
- **JupyterHub**: `http://<cluster-ip>:30888`
- **Argo CD**: `http://<cluster-ip>:30080`
- **Argo Workflows**: `http://<cluster-ip>:32746`
- **Grafana**: `http://<cluster-ip>:30300`
- **Prometheus**: `http://<cluster-ip>:30090`
- **MinIO Console**: `http://<cluster-ip>:30901`
- **Kubernetes Dashboard**: `http://<cluster-ip>:30443`

## Directory Structure

### Core Infrastructure
- `infrastructure/cluster/site.yml` - Main Ansible playbook for complete deployment
- `infrastructure/cluster/roles/` - Modular Ansible roles for each component
- `inventory/production/` - Cluster configuration and host definitions

### Key Ansible Roles
- `foundation/k3s_control_plane` - K3s master node setup
- `foundation/k3s_workers` - K3s worker node setup
- `foundation/metallb` - MetalLB load balancer for bare-metal
- `foundation/sealed_secrets` - Sealed Secrets controller
- `mlops/mlflow` - MLflow deployment with PostgreSQL backend
- `platform/seldon` - Seldon Core model serving
- `platform/jupyterhub` - JupyterHub collaborative environment
- `platform/argo_cd` - ArgoCD GitOps deployment
- `monitoring/prometheus_stack` - Prometheus + Grafana monitoring

### Configuration Files
- `inventory/production/group_vars/all.yml` - Global platform configuration
- `values/storage-defaults.yaml` - Storage configuration defaults
- `infrastructure/manifests/` - Kubernetes manifests and sealed secrets

## Development Workflow

### Adding New Components
1. Create Ansible role in `infrastructure/cluster/roles/`
2. Add role to appropriate phase in `site.yml`
3. Configure secrets in `scripts/create-all-sealed-secrets.sh`
4. Update inventory variables if needed
5. Test deployment on development cluster

### Modifying Existing Services
1. Update relevant Ansible role in `infrastructure/cluster/roles/`
2. Modify configuration in `inventory/production/group_vars/all.yml`
3. Update secrets if credentials change
4. Deploy specific component with `--tags` flag

### Secret Management Pattern
- Secrets are managed via Sealed Secrets controller
- Use `scripts/create-sealed-secret.sh` to create new secrets
- All secrets are GitOps-safe and can be committed to repository
- Secrets auto-decrypt when applied to cluster with matching private key

## CNI Migration (Current Branch)

The current branch `infrastructure/calico-migration` implements migration from Flannel to Calico CNI:
- **Reason**: Seldon Core v2 requires Calico for proper network policy support
- **Implementation**: Automated migration in `foundation/k3s_control_plane/tasks/calico.yml`
- **Configuration**: Calico settings in `infrastructure/cluster/roles/foundation/k3s_control_plane/templates/calico-installation.yaml.j2`

### Network Policy Fix

**Issue**: After Calico migration, DNS resolution timeouts between ML pods and CoreDNS caused model deployment failures.

**Root Cause**: Network policies in ML namespaces blocked DNS traffic to kube-system namespace.

**Solution**: Updated Seldon role to automatically:
- Label kube-system namespace with `name=kube-system`
- Create network policies that allow DNS egress to kube-system:53
- Enable secure communication between ML namespaces and seldon-system
- Allow external HTTPS/HTTP access for model downloads

**Configuration**: 
```yaml
# In seldon defaults
seldon_enable_network_policies: true
seldon_ml_namespaces:
  - financial-ml
```

## MetalLB Integration

MetalLB is fully integrated with Istio and Seldon Core v2:
- **Istio Gateway**: Automatically switches to LoadBalancer type when MetalLB is enabled
- **Seldon Core v2**: Optional LoadBalancer service for external access to model endpoints
- **IP Pool**: Configured for 192.168.1.200-250 range (configurable)
- **Shared IPs**: Supports multiple services sharing the same external IP

## Testing

### Platform Validation
```bash
# Test cluster deployment
ansible-playbook -i inventory/production/hosts infrastructure/cluster/roles/tests/test.yml

# Validate services
kubectl get pods --all-namespaces
kubectl get svc --all-namespaces
```

### Component Testing
- Individual role tests in `infrastructure/cluster/roles/*/tests/test.yml`
- Integration tests via MLflow tracking and model deployment
- Monitoring dashboards for health validation

## Network Policy Management

### Platform vs Application Responsibility

**Platform Team Manages:**
- Cluster-wide network policies (DNS resolution, cross-namespace communication)
- Baseline network policies for ML namespaces via Ansible automation
- Infrastructure connectivity (seldon-system, kube-system access)
- Security compliance and policy templates

**Application Team Manages:**
- Application-specific network policies within assigned namespaces
- Service-to-service communication rules for business logic
- External service access requirements (model downloads, telemetry)
- Layered policies on top of platform baseline

### Network Policy Workflow

```bash
# Platform: Add namespace to configuration
# Edit: inventory/production/group_vars/all.yml
seldon_ml_namespaces:
  - financial-ml
  - new-ml-project

# Platform: Deploy baseline policies
ansible-playbook -i inventory/production/hosts infrastructure/cluster/site.yml --tags seldon

# Application: Deploy additional policies
kubectl apply -f k8s/base/network-policy.yaml -n financial-ml
```

See `docs/network-policies.md` for complete documentation and policy templates.

## Troubleshooting

### Common Issues
- **Sealed Secrets not decrypting**: Check controller logs and private key
- **MLflow connection issues**: Verify PostgreSQL connectivity and credentials
- **Storage issues**: Check NFS mounts and MinIO service status
- **Service mesh issues**: Ensure Istio is properly configured for KServe
- **DNS resolution failures**: Check network policies allow port 53 to kube-system
- **Cross-namespace communication**: Verify namespace labels and network policy rules

### Debug Commands
```bash
# Check sealed secrets controller
kubectl logs -n sealed-secrets controller-sealed-secrets

# MLflow troubleshooting
kubectl logs -n mlflow deployment/mlflow-server
kubectl describe pod -n mlflow

# Check persistent volumes
kubectl get pv,pvc --all-namespaces

# Ansible fact gathering issues
ansible k3s_control_plane -i inventory/production/hosts -m setup
ansible-playbook -i inventory/production/hosts infrastructure/cluster/site.yml --tags k3s -vvv
```

## Important Notes

- Platform supports both development and production environments
- All components are designed for high availability and scalability
- Monitoring is built-in with Prometheus and Grafana
- Security follows enterprise best practices with RBAC and sealed secrets
- GitOps approach enables version-controlled infrastructure management
- Current focus is on Flannel to Calico CNI migration for Seldon Core v2 compatibility