# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a production-ready MLOps platform built on K3s (lightweight Kubernetes) with infrastructure automation via Ansible. The platform provides end-to-end ML lifecycle management including experiment tracking, model serving, pipeline orchestration, and comprehensive monitoring.

## Architecture

### Infrastructure Layer
- **K3s Cluster**: 1 control plane + 4 worker nodes (36 CPU cores, 260GB RAM total)
- **CNI**: Cilium (default, resolves Calico ARP bug #8689)
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
ansible-playbook -i inventory/production/hosts infrastructure/cluster/site.yml --tags harbor

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
- **MLflow**: `http://192.168.1.201:5000` (LoadBalancer) or `http://<cluster-ip>:30800` (NodePort fallback)
- **MinIO API**: `http://192.168.1.200:9000` (LoadBalancer) or `http://<cluster-ip>:30900` (NodePort fallback)
- **MinIO Console**: `http://192.168.1.202:9001` (LoadBalancer) or `http://<cluster-ip>:30901` (NodePort fallback)
- **Harbor Registry**: `http://192.168.1.210:80` (LoadBalancer) or `http://<cluster-ip>:30880` (NodePort fallback)
- **JupyterHub**: `http://<cluster-ip>:30888`
- **Argo CD**: `http://<cluster-ip>:30080`
- **Argo Workflows**: `http://<cluster-ip>:32746`
- **Grafana**: `http://<cluster-ip>:30300`
- **Prometheus**: `http://<cluster-ip>:30090`
- **Kubernetes Dashboard**: `http://<cluster-ip>:30443`

### Stable Service Configuration

For consistent service access across deployments, use LoadBalancer endpoints:

```bash
# Stable endpoints (recommended with MetalLB)
export MLFLOW_TRACKING_URI=http://192.168.1.201:5000
export MINIO_ENDPOINT=http://192.168.1.200:9000
export HARBOR_REGISTRY=http://192.168.1.210

# Deploy platform with MetalLB LoadBalancer support
ansible-playbook -i inventory/production/hosts infrastructure/cluster/site.yml -e metallb_state=present
```

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
- `platform/harbor` - Harbor container registry
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

## Harbor Container Registry

Harbor is integrated as the platform's container registry, providing secure image storage, vulnerability scanning, and content signing capabilities.

### Harbor Configuration

```yaml
# Harbor Registry Settings
harbor_namespace: "harbor"
harbor_nodeport: 30880
harbor_loadbalancer_ip: "192.168.1.210"
harbor_admin_password: "set-via-environment-or-vault"
harbor_trivy_enabled: true
harbor_notary_enabled: true
harbor_chartmuseum_enabled: true
```

### Harbor Usage

```bash
# Login to Harbor registry
docker login 192.168.1.210 -u admin -p $HARBOR_ADMIN_PASSWORD

# Tag and push image
docker tag myapp:latest 192.168.1.210/library/myapp:latest
docker push 192.168.1.210/library/myapp:latest

# Pull image
docker pull 192.168.1.210/library/myapp:latest

# Create project via Harbor UI
# Navigate to http://192.168.1.210 → Projects → New Project
```

### Harbor Integration

Harbor is automatically integrated with:
- **Seldon Core**: Registry secrets created for model serving
- **JupyterHub**: Registry access for notebook environments
- **Kubernetes**: Service accounts configured with pull secrets

### Harbor Features

- **Vulnerability Scanning**: Trivy integration for security analysis
- **Content Trust**: Notary service for image signing
- **Helm Charts**: ChartMuseum for Helm chart repository
- **RBAC**: Role-based access control for projects and repositories
- **Replication**: Cross-registry replication support
- **Webhook**: Integration with CI/CD pipelines

## Troubleshooting

### Common Issues
- **Sealed Secrets not decrypting**: Check controller logs and private key
- **MLflow connection issues**: Verify PostgreSQL connectivity and credentials
- **Storage issues**: Check NFS mounts and MinIO service status
- **Service mesh issues**: Ensure Istio is properly configured for KServe
- **DNS resolution failures**: Check network policies allow port 53 to kube-system
- **Cross-namespace communication**: Verify namespace labels and network policy rules
- **Harbor registry issues**: Check persistent volume claims and database connectivity
- **Container image push failures**: Verify Harbor admin credentials and network connectivity

### Debug Commands
```bash
# Check sealed secrets controller
kubectl logs -n sealed-secrets controller-sealed-secrets

# MLflow troubleshooting
kubectl logs -n mlflow deployment/mlflow-server
kubectl describe pod -n mlflow

# Check persistent volumes
kubectl get pv,pvc --all-namespaces

# Harbor troubleshooting
kubectl logs -n harbor deployment/harbor-core
kubectl get pods -n harbor
kubectl get svc -n harbor

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
- Harbor registry provides secure container image storage with vulnerability scanning
- Current focus is on Flannel to Calico CNI migration for Seldon Core v2 compatibility

## Development Guidelines

- **YAML Template Rule**: Never mix Jinja2 templating syntax in YAML values - use conditional Ansible tasks instead
- **Service Pattern**: Use separate tasks for LoadBalancer (MetalLB) vs NodePort (fallback) service types
- **Infrastructure as Code**: Always prefer updating and testing Ansible plays over patching resources directly with kubectl
- **TLS Certificate Fix**: Anytime you see `x509: certificate signed by unknown authority` error, run:
  ```bash
  ssh 192.168.1.85 "sudo cat /etc/rancher/k3s/k3s.yaml" | sed -e 's/127.0.0.1/192.168.1.85/' > ~/.kube/config
  ```
- **Documentation**: Always update CLAUDE.md when adding new operational patterns

## Job-Seeking Context

**MLOps Engineer Portfolio Evidence**: This repository demonstrates production-grade MLOps platform engineering skills. For job applications:

**Recommended Git Attribution**:
- **Personal commits**: Show your technical decision-making and platform design skills
- **AI-assisted commits**: Be transparent about AI collaboration while emphasizing your orchestration and validation
- **Example**: "Implement Calico CNI migration strategy (AI-assisted research and validation)"

**Key Demonstration Areas**:
- Infrastructure as Code (Ansible, K3s, Calico networking)
- Platform reliability engineering (data persistence, service mesh)
- MLOps stack integration (MLflow, Seldon, Argo workflows)
- Production troubleshooting and incident response

**Value Proposition**: Shows ability to leverage modern AI tools effectively while maintaining technical ownership and validation of solutions - a crucial skill for 2025+ MLOps roles.

## Article Documentation

**Instruction:** Document the CNI migration experience in a comprehensive article covering:
- Technical root cause analysis of CIDR configuration mismatches
- Platform vs application team responsibility boundaries for network policies  
- Production debugging techniques for Kubernetes networking issues
- Automation strategies for CNI management and validation
- Real-world lessons learned from migrating production ML workloads

See `ARTICLE_OUTLINE.md` for detailed table of contents and key points to cover.
The article should serve as a practical guide for platform engineers facing similar CNI migration challenges.