# Infrastructure Restructure Plan

## Executive Summary

This plan restructures the MLOps platform infrastructure roles from a monolithic approach to a layered, concern-based architecture. The transformation improves maintainability, reusability, and scalability while preserving all existing functionality.

## Current State Analysis

### Current Role Distribution
```
foundation/          (19 roles) - Mixed concerns: bootstrap, cluster, networking, storage, security
├── Prerequisites, platform_detection (bootstrap)
├── k3s_control_plane, k3s_workers, kubeadm_cluster, eks_cluster (cluster)
├── cilium, metallb, coredns-test-domains (networking)
├── nfs_server, nfs_clients, nfs_provisioner (storage)
├── sealed_secrets, secrets, harbor-certs (security)
└── kafka (messaging)

platform/            (8 roles) - Mixed platform and MLOps concerns
├── argo_cd, argo_workflows, argo_events (GitOps)
├── dashboard, harbor, istio, jupyterhub (platform)
└── seldon (MLOps serving)

mlops/              (3 roles) - Pure MLOps
├── mlflow, kubeflow, kserve

monitoring/         (1 role) - Observability
└── prometheus_stack

storage/            (2 roles) - Storage utilities
└── minio, credentials
```

### Key Issues Identified
1. **Mixed Concerns**: Foundation layer contains everything from prerequisites to messaging
2. **Duplicate Logic**: k3s_control_plane + k3s_workers have overlapping functionality
3. **Unclear Dependencies**: Role execution order is buried in site.yml phases
4. **Provider Coupling**: Platform-specific logic scattered across multiple roles
5. **Testing Isolation**: Test utilities mixed with production components

## Target Architecture

### New Directory Structure
```
infrastructure/cluster/
├── inventories/                 # Environment-specific inventory & vars
│   ├── dev/
│   ├── staging/
│   └── prod/
├── group_vars/                 # Provider and role-specific variables
│   ├── all/
│   ├── k3s/
│   ├── kubeadm/
│   └── eks/
├── playbooks/                  # Layered, purpose-built playbooks
│   ├── site.yml                # Master entrypoint (tags drive layers)
│   ├── bootstrap.yml           # Pre-requisites only
│   ├── cluster.yml             # Control-plane + workers + CNI
│   ├── platform.yml            # Argo, registry, ingress, etc.
│   ├── mlops.yml              # ML-specific services
│   └── observability.yml       # Monitoring and observability
└── roles/
    ├── bootstrap/              # Host-level preparation
    │   ├── prerequisites       # Packages, kernel mods, swap, time
    │   └── platform_detection  # Fact setting; keep tiny & pure
    │
    ├── cluster/                # Cluster creation & core add-ons
    │   ├── k3s                 # Unified with node_role=[server,agent]
    │   ├── kubeadm             # Standard Kubernetes
    │   ├── eks                 # AWS managed Kubernetes
    │   ├── kubeconfig          # Config fetching and setup
    │   └── cni/
    │       ├── cilium
    │       ├── calico
    │       └── flannel
    │
    ├── networking/             # Networking components
    │   ├── core_dns            # CoreDNS management (not test domains)
    │   ├── metallb
    │   └── test_domains        # Clearly marked as test-only
    │
    ├── storage/                # Storage solutions
    │   ├── nfs/
    │   │   ├── server
    │   │   ├── provisioner
    │   │   └── clients
    │   ├── minio
    │   └── credentials         # S3/registry creds (templated secrets)
    │
    ├── security/               # Security components
    │   ├── sealed_secrets
    │   ├── secrets             # App/platform secrets (generic; uses vars)
    │   └── certs/
    │       ├── harbor
    │       └── ca              # Trust chain, bundle distribution
    │
    ├── platform/               # Cluster-wide platform services
    │   ├── argo/
    │   │   ├── cd
    │   │   ├── workflows
    │   │   └── events
    │   ├── ingress/            # Istio or NGINX via var toggle
    │   │   ├── istio
    │   │   └── nginx
    │   ├── registry/
    │   │   └── harbor
    │   ├── dashboard
    │   └── data/
    │       ├── kafka
    │       └── redis
    │
    ├── mlops/                  # ML-specific services
    │   ├── mlflow
    │   ├── kserve              # Separate from istio ingress concerns
    │   ├── kubeflow            # Optional, large; gated by tag
    │   └── seldon
    │
    └── observability/          # Monitoring and observability
        ├── prometheus_stack
        ├── loki
        └── jaeger

utilities/                      # Ad-hoc helpers, not roles
├── kube_helpers/               # kubectl wrappers, context management
└── scripts/                    # Migration and utility scripts
```

## Transformation Phases

### Phase 1: Directory Structure Creation
**Objective**: Establish new directory structure without disrupting current functionality

**Actions**:
1. Create new directory hierarchy
2. Preserve existing roles in place during transition
3. Set up environment-specific inventories
4. Create group_vars for different providers

**Deliverables**:
- New directory structure
- Environment-specific inventory templates
- Provider-specific group_vars

### Phase 2: Bootstrap Layer Migration
**Objective**: Move foundation prerequisites and platform detection to bootstrap layer

**Current → New Mapping**:
```
foundation/prerequisites → bootstrap/prerequisites
foundation/platform_detection → bootstrap/platform_detection
```

**Key Changes**:
- Consolidate package installation, kernel modules, swap management
- Make platform detection pure (no side effects, only fact gathering)
- Remove provider-specific logic from prerequisites

### Phase 3: Cluster Layer Consolidation
**Objective**: Consolidate cluster creation roles and separate CNI concerns

**Current → New Mapping**:
```
foundation/k3s_control_plane + foundation/k3s_workers → cluster/k3s
foundation/kubeadm_cluster → cluster/kubeadm
foundation/eks_cluster → cluster/eks
foundation/fetch_kubeconfig → cluster/kubeconfig
foundation/cilium → cluster/cni/cilium
```

**Key Changes**:
- **Unified k3s role**: Use `node_role` parameter (server/agent) instead of separate roles
- **Provider abstraction**: Use `cluster_provider` variable to select implementation
- **CNI separation**: Move networking concerns to dedicated CNI roles
- **Reusable patterns**: Share common tasks across providers

### Phase 4: Networking Layer Reorganization
**Objective**: Separate core networking from test utilities and load balancing

**Current → New Mapping**:
```
foundation/metallb → networking/metallb
foundation/coredns-test-domains → networking/test_domains
(new) → networking/core_dns
```

**Key Changes**:
- Extract CoreDNS management from test domains
- Clearly mark test utilities as non-production
- Centralize networking policy management

### Phase 5: Storage Layer Consolidation
**Objective**: Group all storage-related concerns together

**Current → New Mapping**:
```
foundation/nfs_server → storage/nfs/server
foundation/nfs_clients → storage/nfs/clients
foundation/nfs_provisioner → storage/nfs/provisioner
storage/minio → storage/minio
storage/credentials → storage/credentials
```

**Key Changes**:
- Consolidate NFS components with clear separation
- Standardize credential management patterns
- Support multiple storage backends

### Phase 6: Security Layer Enhancement
**Objective**: Centralize security components and credential management

**Current → New Mapping**:
```
foundation/sealed_secrets → security/sealed_secrets
foundation/secrets → security/secrets
foundation/harbor-certs → security/certs/harbor
(new) → security/certs/ca
```

**Key Changes**:
- Centralize certificate management
- Standardize secret creation patterns
- Add CA trust chain management

### Phase 7: Platform Layer Restructuring
**Objective**: Separate platform infrastructure from MLOps services

**Current → New Mapping**:
```
platform/argo_cd → platform/argo/cd
platform/argo_workflows → platform/argo/workflows
platform/argo_events → platform/argo/events
platform/istio → platform/ingress/istio
platform/harbor → platform/registry/harbor
platform/dashboard → platform/dashboard
foundation/kafka → platform/data/kafka
platform/jupyterhub → platform/jupyterhub (temporary, may move to mlops)
platform/seldon → mlops/seldon
```

**Key Changes**:
- Group Argo components together
- Separate ingress providers (Istio vs NGINX)
- Move data services to platform/data
- Relocate MLOps-specific services

### Phase 8: MLOps Layer Refinement
**Objective**: Consolidate ML-specific services with clear dependencies

**Current → New Mapping**:
```
mlops/mlflow → mlops/mlflow
mlops/kubeflow → mlops/kubeflow
mlops/kserve → mlops/kserve
platform/seldon → mlops/seldon
```

**Key Changes**:
- Move Seldon from platform to MLOps
- Clarify dependencies on platform services
- Add ML workflow orchestration patterns

### Phase 9: Observability Layer Expansion
**Objective**: Prepare for comprehensive observability stack

**Current → New Mapping**:
```
monitoring/prometheus_stack → observability/prometheus_stack
(future) → observability/loki
(future) → observability/jaeger
```

## Implementation Strategy

### 1. Role Design Patterns

**Variable-First Approach**:
```yaml
# Standard variables for all roles
cluster_provider: k3s|kubeadm|eks
node_role: server|agent|master|worker
cluster_name: "{{ cluster_name | default('k8s-cluster') }}"
ingress_provider: istio|nginx
storage_provider: nfs|ceph|ebs
enable_feature_flags: true
```

**Meta Dependencies**:
```yaml
# roles/mlops/kserve/meta/main.yml
dependencies:
  - role: platform/ingress/istio
    when: ingress_provider == 'istio'
  - role: security/sealed_secrets
```

**Conditional Execution**:
```yaml
# Use when conditions instead of mixing providers in single role
- name: Deploy k3s cluster
  include_role:
    name: cluster/k3s
  when: cluster_provider == 'k3s'

- name: Deploy kubeadm cluster  
  include_role:
    name: cluster/kubeadm
  when: cluster_provider == 'kubeadm'
```

### 2. Layered Playbook Architecture

**Master Playbook** (`playbooks/site.yml`):
```yaml
---
- name: MLOps Platform Deployment
  hosts: all
  gather_facts: yes
  
  tasks:
    - import_playbook: bootstrap.yml
      tags: [bootstrap]
      
    - import_playbook: cluster.yml  
      tags: [cluster]
      
    - import_playbook: platform.yml
      tags: [platform]
      
    - import_playbook: mlops.yml
      tags: [mlops]
      
    - import_playbook: observability.yml
      tags: [observability]
```

**Cluster Playbook** (`playbooks/cluster.yml`):
```yaml
---
- hosts: k8s_control_plane
  tags: cluster
  roles:
    - role: cluster/{{ cluster_provider }}
      node_role: "{{ 'server' if cluster_provider == 'k3s' else 'master' }}"
    - role: cluster/cni/{{ cni_provider }}

- hosts: k8s_workers  
  tags: cluster
  roles:
    - role: cluster/{{ cluster_provider }}
      node_role: "{{ 'agent' if cluster_provider == 'k3s' else 'worker' }}"
```

### 3. Unified k3s Role Example

**New Structure** (`roles/cluster/k3s/`):
```
tasks/
├── main.yml              # Route to server or agent tasks
├── server.yml            # Control plane installation
├── agent.yml             # Worker node installation  
├── common.yml            # Shared tasks (firewall, etc.)
└── validate.yml          # Health checks

defaults/main.yml         # Combined defaults
vars/main.yml            # Platform-specific vars
templates/               # Config templates
tests/                   # Molecule tests
```

**Task Routing**:
```yaml
# roles/cluster/k3s/tasks/main.yml
---
- name: Install k3s common components
  include_tasks: common.yml
  tags: [k3s, common]

- name: Install k3s server
  include_tasks: server.yml  
  when: node_role == 'server'
  tags: [k3s, server]

- name: Install k3s agent
  include_tasks: agent.yml
  when: node_role == 'agent'  
  tags: [k3s, agent]

- name: Validate k3s installation
  include_tasks: validate.yml
  tags: [k3s, validate]
```

### 4. Environment-Specific Configuration

**Development Profile** (`inventories/dev/group_vars/all.yml`):
```yaml
cluster_provider: k3s
cni_provider: cilium
ingress_provider: istio
storage_provider: nfs

# Minimal feature set for development
enable_harbor: false
enable_kubeflow: false
enable_monitoring: true
enable_mlflow: true

# Resource constraints
metallb_ip_range: "192.168.1.200-210" 
k3s_server_resources:
  memory: "2Gi"
  cpu: "1000m"
```

**Production Profile** (`inventories/prod/group_vars/all.yml`):  
```yaml
cluster_provider: kubeadm
cni_provider: calico
ingress_provider: istio
storage_provider: ceph

# Full feature set for production
enable_harbor: true
enable_kubeflow: true
enable_monitoring: true
enable_mlflow: true
enable_ha: true

# Production resources
metallb_ip_range: "192.168.1.200-250"
kubeadm_cluster_config:
  controlPlaneEndpoint: "k8s-api.example.com:6443"
  etcd:
    external:
      endpoints: [...] 
```

## Migration Execution Plan

### Step 1: Parallel Structure Creation (Week 1)
- Create new directory structure alongside existing
- Set up basic inventories and group_vars
- Create placeholder roles with README files
- No disruption to existing deployment capability

### Step 2: Bootstrap Migration (Week 2)  
- Migrate and test `prerequisites` and `platform_detection`
- Create `bootstrap.yml` playbook
- Test deployment with new bootstrap layer
- Keep fallback to old structure

### Step 3: Cluster Layer Migration (Week 3-4)
- **Priority**: Unified k3s role (most complex)
- Migrate kubeadm and EKS roles
- Extract CNI to separate roles
- Create `cluster.yml` playbook
- Extensive testing across all providers

### Step 4: Supporting Layers (Week 5-6)
- Migrate networking, storage, security layers
- Update dependencies and meta files
- Test integration between layers

### Step 5: Platform & MLOps Migration (Week 7-8)
- Reorganize platform services by concern
- Move MLOps services to dedicated layer
- Create specialized playbooks
- Update all cross-dependencies

### Step 6: Integration Testing (Week 9)
- End-to-end testing of new structure
- Performance benchmarking
- Documentation updates
- Migration scripts for existing deployments

### Step 7: Cutover & Cleanup (Week 10)
- Update main site.yml to use new structure
- Archive old role structure
- Update CI/CD pipelines
- Team training and documentation

## Risk Mitigation

### Deployment Continuity
- Maintain parallel structure during migration
- Feature flags to switch between old/new implementations
- Comprehensive rollback procedures
- Blue/green testing approach

### Dependency Management
- Explicit dependency mapping in meta files
- Variable validation in all roles
- Integration test coverage for role combinations
- Clear error messages for missing dependencies

### Team Coordination
- Weekly migration checkpoints
- Shared testing environment
- Documentation updates in real-time
- Code review requirements for structural changes

## Success Metrics

### Technical Metrics
- **Deployment Time**: Target 20% reduction through better parallelization
- **Role Reusability**: 90% of roles work across dev/staging/prod
- **Test Coverage**: 100% of roles have basic smoke tests
- **Dependency Clarity**: Zero hidden dependencies between layers

### Operational Metrics  
- **Time to Add New Component**: Target 50% reduction
- **Configuration Drift**: Eliminate through better variable management
- **Documentation Accuracy**: 100% of roles have current README
- **Team Velocity**: Maintain current sprint capacity during migration

## Conclusion

This restructure transforms the infrastructure from a monolithic, tightly-coupled approach to a layered, concern-based architecture. The new structure will:

1. **Improve Maintainability**: Clear separation of concerns and standardized patterns
2. **Enhance Reusability**: Provider-agnostic roles that work across environments
3. **Increase Scalability**: Layered approach supports incremental feature additions
4. **Reduce Complexity**: Eliminate duplicate logic and hidden dependencies
5. **Accelerate Development**: Faster onboarding and feature development cycles

The phased migration approach ensures continuous deployment capability while systematically improving the infrastructure foundation.