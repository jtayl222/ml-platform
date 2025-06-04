# Kubernetes Cluster Roles

This directory contains Ansible roles for deploying and managing Kubernetes cluster components.

## Available Roles

### sealed_secrets

Deploys and manages Sealed Secrets controller for encrypting Kubernetes secrets.

**Purpose**: 
- Install Sealed Secrets controller via Helm
- Create required namespaces
- Generate sealed secrets from scripts
- Apply sealed secret manifests to cluster

**Requirements**:
- Kubernetes cluster must be running
- `kubectl` and `kubeseal` CLI tools installed
- Helm repositories accessible
- Valid kubeconfig file

**Variables**:
```yaml
kubeconfig_path: "/path/to/kubeconfig"  # Required
playbook_dir: "{{ ansible_playbook_dir }}"  # Auto-detected
```

**Dependencies**:
- `fetch_kubeconfig` role (must run first)
- Kubernetes cluster must be ready
- `kubernetes.core` Ansible collection

**Tags**:
- `sealed-secrets` - Run entire role
- `controller` - Deploy only the controller
- `namespaces` - Create only namespaces
- `scripts` - Run only script generation
- `manifests` - Apply only manifests

**Usage**:
```yaml
# In your playbook
- name: Deploy Sealed Secrets
  include_role:
    name: sealed_secrets
  tags: [security, sealed-secrets]
```

**Command line examples**:
```bash
# Deploy everything
ansible-playbook site.yml --tags="sealed-secrets"

# Deploy only controller
ansible-playbook site.yml --tags="controller"

# Generate and apply secrets only
ansible-playbook site.yml --tags="scripts,manifests"
```

**Files created**:
- Sealed Secrets controller in `kube-system` namespace
- Application namespaces: minio, monitoring, argowf, argocd, mlflow
- Sealed secret manifests in `infrastructure/manifests/sealed-secrets/`

### Other Roles

Additional roles can be documented here as they are created.

## License

MIT

## Author Information

K3s Homelab MLOps Platform
