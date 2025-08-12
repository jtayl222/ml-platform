# MLOps Platform Ansible Roles

This directory contains modular Ansible roles for deploying a production-ready MLOps platform. Each role is self-contained and follows Ansible best practices.

## Directory Structure

```
roles/
├── foundation/          # Core infrastructure components
│   ├── prerequisites/   # Platform prerequisites (yq, helm, kubectl) ⭐ CRITICAL FIRST
│   ├── platform_detection/ # Multi-platform K8s detection
│   ├── k3s_control_plane/
│   ├── k3s_workers/
│   ├── metallb/
│   ├── sealed_secrets/
│   └── ...
├── platform/           # Platform services
│   ├── istio/          # Service mesh v1.27.x + Kiali + Jaeger
│   ├── harbor/         # Enterprise container registry
│   ├── argo_cd/
│   └── ...
├── mlops/              # ML-specific services
│   ├── mlflow/
│   ├── seldon/
│   └── ...
├── monitoring/         # Observability stack
│   └── prometheus_stack/
├── storage/            # Storage services
│   ├── minio/
│   └── ...
└── tests/              # Platform verification and testing ⭐ NEW
    ├── tasks/          # Comprehensive health checks
    └── defaults/       # Test configuration
```

## Critical Prerequisites Role ⚠️

The `prerequisites` role **MUST** run first and solves critical platform issues:

**What it fixes:**
- ✅ **yq Version Conflicts**: Installs correct yq v4 (Go-based), prevents sealed secrets failures
- ✅ **Tool Consistency**: Standardizes Helm v3, kubectl, system dependencies
- ✅ **Shell Compatibility**: POSIX-compliant scripts for cross-platform support
- ✅ **Python Environment**: Handles externally-managed environment restrictions

**Problems it prevents:**
- ❌ Sealed secrets generating empty files (wrong yq version)
- ❌ Harbor role reinstalling conflicting tool versions  
- ❌ Platform deployment failures due to missing dependencies

## Role Categories

### Foundation Roles (Phase 0-2)
Core infrastructure that other services depend on:
- **prerequisites**: Essential platform tools - **RUN FIRST**
- **platform_detection**: Auto-detect K3s, Kubeadm, or EKS
- **k3s_control_plane**: Kubernetes control plane with Cilium CNI
- **metallb**: Load balancer for bare-metal LoadBalancer services
- **sealed_secrets**: GitOps-safe credential management

### Platform Roles (Phase 3-4)
Application platform services:
- **istio**: Service mesh v1.27.x with Kiali v1.85 + Jaeger observability
- **harbor**: Enterprise registry with vulnerability scanning & 4-tier replication
- **argo_cd**: GitOps continuous deployment
- **jupyterhub**: Collaborative data science environment

### MLOps Roles (Phase 5)
Machine learning specific services:
- **mlflow**: Experiment tracking with PostgreSQL backend
- **seldon**: Production model serving platform
- **kserve**: Kubernetes-native model serving (requires Istio)

### Monitoring & Storage
Supporting infrastructure:
- **prometheus_stack**: Comprehensive monitoring with Grafana
- **minio**: S3-compatible object storage

### Testing & Verification ⭐ NEW
Platform validation and health checks:
- **tests**: Automated verification following industry best practices

## Platform Verification

Following enterprise standards, the platform includes comprehensive testing:

```bash
# Quick health check script
./scripts/verify-platform.sh

# Comprehensive Ansible-based tests
ansible-playbook infrastructure/cluster/test-platform.yml

# What gets verified:
# ✅ Platform prerequisites (yq v4, Helm v3, kubectl)
# ✅ Cluster health (nodes, pods, resources)  
# ✅ Core services (storage, networking, security)
# ✅ MLOps stack (MLflow, Seldon, JupyterHub)
# ✅ Service endpoints (LoadBalancer IPs, API connectivity)
# ✅ ML workflow (experiment tracking, model serving)
```

## Usage

Roles are designed for the main site playbooks:

```bash
# Deploy entire platform (auto-includes prerequisites)
ansible-playbook -i inventory/production/hosts infrastructure/cluster/site.yml

# Multi-platform deployment with detection
ansible-playbook -i inventory/production/hosts infrastructure/cluster/site-multiplatform.yml

# Deploy specific components
ansible-playbook site.yml --tags prerequisites  # Install tools first
ansible-playbook site.yml --tags istio         # Service mesh
ansible-playbook site.yml --tags mlflow        # ML tracking

# Run verification tests
ansible-playbook infrastructure/cluster/test-platform.yml
```

## Multi-Platform Support

All roles support multiple Kubernetes distributions:
- **K3s**: Lightweight, edge-optimized (default Cilium CNI)
- **Kubeadm**: Standard Kubernetes for on-premises (Calico CNI)
- **EKS**: AWS managed Kubernetes (VPC CNI)

Platform detection and optimization is handled automatically.

## Development Guidelines

When creating or modifying roles:

1. **Never Install Tools**: Don't install yq, helm, kubectl - use `prerequisites` role
2. **Shell Compatibility**: Use POSIX syntax, avoid bash `[[` constructs
3. **Tool Paths**: Reference tools via variables like `{{ platform_yq_path }}`
4. **Standard Structure**: Follow Ansible role directory conventions
5. **Comprehensive Defaults**: Document all variables in `defaults/main.yml`
6. **Proper Tagging**: Enable selective deployment with meaningful tags
7. **Testing**: Add verification tasks and health checks
8. **Documentation**: Complete README with examples and troubleshooting

## Dependencies

Deployment order is enforced through role dependencies:

```
prerequisites → platform_detection → foundation → platform → mlops → tests
```

## Industry Best Practices Implemented

✅ **Tool Version Management**: Single source of truth for platform dependencies  
✅ **Cross-Platform Compatibility**: POSIX-compliant automation  
✅ **Comprehensive Testing**: Automated health checks and validation  
✅ **GitOps Integration**: Sealed secrets for credential management  
✅ **Service Mesh Observability**: Full Istio + Kiali + Jaeger stack  
✅ **Enterprise Registry**: Harbor with security scanning  
✅ **Multi-Platform Support**: K3s, Kubeadm, EKS deployment flexibility
