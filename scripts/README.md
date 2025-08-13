# Scripts Documentation

## Platform Deployment Scripts

### bootstrap-k3s.sh
Bootstraps the complete MLOps platform on K3s cluster.

```bash
./scripts/bootstrap-k3s.sh
```

### bootstrap-kubeadm.sh  
Bootstraps the complete MLOps platform on kubeadm cluster with HA control plane.

```bash
./scripts/bootstrap-kubeadm.sh
```

### bootstrap-eks.sh
Bootstraps the complete MLOps platform on Amazon EKS.

Prerequisites: AWS CLI, eksctl, valid AWS credentials

```bash
./scripts/bootstrap-eks.sh
```

### delete_k3s.sh
Completely removes K3s cluster and cleans up storage.

```bash
./scripts/delete_k3s.sh
```

### delete_kubeadm.sh
Completely removes kubeadm cluster and cleans up nodes.

**What it does:**
- Removes kubeadm cluster using Ansible (all control plane and worker nodes)
- Stops containerd to ensure all containers are terminated
- Removes all container images and snapshots
- Cleans up CNI configurations and Cilium network interfaces
- Removes Kubernetes packages from nodes
- Cleans up local kubeconfig files

**Note:** This performs a complete cleanup. Containerd will be left stopped.
Run bootstrap-kubeadm.sh to redeploy.

```bash
./scripts/delete_kubeadm.sh
```

### add-kubeadm-control-plane.sh
Adds additional control plane nodes to existing kubeadm cluster for high availability.

**Prerequisites:**
- Existing kubeadm cluster with at least one control plane node
- New node(s) added to inventory under `[kubeadm_control_plane]`
- SSH access to target nodes

**Usage:**
```bash
# Add a specific control plane node
./scripts/add-kubeadm-control-plane.sh --node nuc10i3-2

# Shows available control plane nodes from inventory
./scripts/add-kubeadm-control-plane.sh
```

**What it does:**
- Validates the target node exists in inventory
- Runs kubeadm join for control plane with proper certificates
- Updates cluster configuration for HA topology
- Verifies new control plane node is ready

### delete_eks.sh
Completely removes EKS cluster and cleans up AWS resources.

```bash
./scripts/delete_eks.sh
```

## Sealed Secrets Management

### create-all-sealed-secrets.sh
Creates all sealed secrets for the platform with environment variable support.

#### Usage:
```bash
# Use defaults (development)
./scripts/create-all-sealed-secrets.sh

# Use custom credentials
export MINIO_ACCESS_KEY="your-key"
export MINIO_SECRET_KEY="your-secret"
./scripts/create-all-sealed-secrets.sh
```

#### Environment Variables:
- `MINIO_ACCESS_KEY` - MinIO access key (default: minioadmin)
- `MINIO_SECRET_KEY` - MinIO secret key (default: minioadmin123)
- `GITHUB_USERNAME` - GitHub username for container registry
- `GITHUB_PAT` - GitHub Personal Access Token
- `GITHUB_EMAIL` - GitHub email address
