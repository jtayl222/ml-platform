# Harbor Certificate Management & Persistence

**Version:** 1.0  
**Date:** July 2025  
**Scope:** Harbor registry TLS certificate management for K3s clusters

---

## 🎯 Overview

This document describes the Harbor certificate management system that ensures TLS certificates persist across K3s cluster rebuilds and provides automated certificate distribution to both cluster nodes and external clients.

### Problem Statement

Harbor registry uses self-signed TLS certificates that must be trusted by:
- **K3s cluster nodes** (for pod image pulls)
- **External clients** (development machines, CI/CD systems)
- **Container runtimes** (Docker, containerd)

When K3s is rebuilt, node-level certificate trust is lost, breaking image pull operations.

### Solution Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                Harbor Certificate Persistence                  │
├─────────────────────────────────────────────────────────────────┤
│  Harbor Registry (harbor namespace)                           │
│  ├── harbor-tls secret ← Source certificate                   │
│  └── Harbor deployment ← Uses certificate for TLS             │
├─────────────────────────────────────────────────────────────────┤
│  Certificate Storage (harbor-certs namespace)                 │
│  ├── harbor-certs-pvc ← Persistent certificate storage        │
│  ├── harbor-cert-init Job ← Extract cert from Harbor secret   │
│  └── harbor-cert-sync DaemonSet ← Distribute to nodes         │
├─────────────────────────────────────────────────────────────────┤
│  K3s Nodes (ephemeral)                                        │
│  ├── /var/lib/rancher/k3s/agent/etc/containerd/certs.d/       │
│  └── Automatically configured by DaemonSet                    │
├─────────────────────────────────────────────────────────────────┤
│  External Clients                                             │
│  ├── Development machines ← Self-service certificate access   │
│  └── CI/CD systems ← Automated certificate distribution       │
└─────────────────────────────────────────────────────────────────┘
```

---

## 📋 Components

### 1. Certificate Storage (PVC)
- **Purpose**: Persistent storage for Harbor certificates
- **Location**: `harbor-certs` namespace
- **Storage**: 1Gi PVC on NFS shared storage
- **Contents**: 
  - `harbor-ca.crt` - Harbor TLS certificate
  - `last-update.txt` - Certificate update timestamp
  - `cert-version.txt` - Kubernetes secret version tracking

### 2. Certificate Initialization Job
- **Purpose**: Extract Harbor certificate from Kubernetes secret to PVC
- **Trigger**: Manual or automated (post-Harbor deployment)
- **Frequency**: When Harbor certificate changes

### 3. Certificate Distribution DaemonSet
- **Purpose**: Automatically configure containerd on all K3s nodes
- **Runs on**: All cluster nodes
- **Configuration**: Places certificates in K3s containerd paths

### 4. External Client Scripts
- **Purpose**: Allow external clients to get certificates from PVC
- **Location**: `scripts/get-harbor-cert-from-pvc.sh`
- **Use cases**: Development machines, CI/CD systems

---

## 🚀 Usage Guide

### For Platform Engineers

#### Initial Setup
```bash
# 1. Deploy Harbor certificate persistence system
kubectl apply -f infrastructure/cluster/roles/foundation/harbor-certs/

# 2. Initialize certificate storage
kubectl create job harbor-cert-refresh --from=job/harbor-cert-init -n harbor-certs

# 3. Verify certificate storage
kubectl exec -n harbor-certs deployment/harbor-cert-sync -- ls -la /persistent-certs/
```

#### After K3s Rebuild
```bash
# 1. Verify Harbor certificate PVC survived
kubectl get pvc -n harbor-certs

# 2. Redistribute certificates to new K3s nodes
kubectl delete pod -n harbor-certs -l app=harbor-cert-sync
kubectl wait --for=condition=Ready pod -n harbor-certs -l app=harbor-cert-sync

# 3. Test Kubernetes image pull
kubectl run harbor-test --image=harbor.test/library/hello-world:test --restart=Never
```

#### Certificate Updates
```bash
# When Harbor certificate changes
kubectl delete job harbor-cert-init -n harbor-certs
kubectl create job harbor-cert-refresh --from=job/harbor-cert-init -n harbor-certs

# Restart DaemonSet to pick up new certificate
kubectl rollout restart daemonset/harbor-cert-sync -n harbor-certs
```

### For Development Teams

#### Initial Setup (New Developer)
```bash
# 1. Get Harbor certificate from cluster
./scripts/get-harbor-cert-from-pvc.sh install

# 2. Verify Harbor access
docker login harbor.test -u admin -p Harbor12345
```

#### After K3s Rebuild
```bash
# Certificate automatically available from PVC
./scripts/get-harbor-cert-from-pvc.sh verify

# If needed, reinstall certificate
./scripts/get-harbor-cert-from-pvc.sh install
```

#### CI/CD Integration
```bash
# In CI/CD pipeline
./scripts/get-harbor-cert-from-pvc.sh show > harbor-ca.crt

# Configure container runtime
mkdir -p /etc/docker/certs.d/harbor.test
cp harbor-ca.crt /etc/docker/certs.d/harbor.test/ca.crt
```

---

## 🔧 Configuration

### Ansible Integration

Add to `infrastructure/cluster/site.yml`:
```yaml
- name: Deploy Harbor Certificate Persistence
  include_role:
    name: foundation/harbor-certs
  tags: [harbor-certs, foundation]
```

### Environment Variables

```yaml
# In group_vars/all.yml
harbor_cert_persistence_enabled: true
harbor_cert_storage_class: "{{ global_storage_class }}"
harbor_cert_storage_size: "1Gi"
harbor_cert_namespace: "harbor-certs"
```

---

## 🛠️ Troubleshooting

### Common Issues

#### 1. Certificate Not Found in PVC
```bash
# Check if initialization job ran
kubectl get job harbor-cert-init -n harbor-certs

# Check job logs
kubectl logs job/harbor-cert-init -n harbor-certs

# Manually run initialization
kubectl delete job harbor-cert-init -n harbor-certs
kubectl create job harbor-cert-refresh --from=job/harbor-cert-init -n harbor-certs
```

#### 2. K3s Nodes Not Trusting Certificate
```bash
# Check DaemonSet status
kubectl get daemonset harbor-cert-sync -n harbor-certs

# Check if certificates are in place
kubectl exec -n harbor-certs ds/harbor-cert-sync -- ls -la /host-containerd/harbor.test/

# Restart DaemonSet pods
kubectl delete pod -n harbor-certs -l app=harbor-cert-sync
```

#### 3. External Client Certificate Issues
```bash
# Check certificate content
./scripts/get-harbor-cert-from-pvc.sh show

# Verify certificate matches Harbor
openssl x509 -in /etc/docker/certs.d/harbor.test/ca.crt -noout -text | grep -A 3 "Subject Alternative Name"

# Reinstall certificate
./scripts/get-harbor-cert-from-pvc.sh install
```

### Verification Commands

```bash
# Check PVC storage
kubectl get pvc harbor-certs-pvc -n harbor-certs

# Check certificate content
kubectl exec -n harbor-certs deployment/harbor-cert-sync -- cat /persistent-certs/harbor-ca.crt

# Test Kubernetes image pull
kubectl run harbor-test --image=harbor.test/library/hello-world:test --restart=Never --rm

# Test external client access
docker login harbor.test -u admin -p Harbor12345
```

---

## 📊 Monitoring

### Key Metrics to Monitor

1. **PVC Storage Usage**
   ```bash
   kubectl get pvc harbor-certs-pvc -n harbor-certs -o jsonpath='{.status.capacity.storage}'
   ```

2. **Certificate Age**
   ```bash
   kubectl exec -n harbor-certs deployment/harbor-cert-sync -- stat /persistent-certs/harbor-ca.crt
   ```

3. **DaemonSet Health**
   ```bash
   kubectl get daemonset harbor-cert-sync -n harbor-certs
   ```

### Alerts to Configure

- PVC storage > 80% full
- DaemonSet pods not ready
- Certificate older than 350 days
- Harbor TLS secret version change

---

## 🔄 Maintenance

### Regular Tasks

#### Weekly
- Verify certificate distribution DaemonSet health
- Check PVC storage usage

#### Monthly
- Test certificate renewal process
- Verify external client access
- Review certificate expiration dates

#### Before K3s Rebuild
- Verify PVC backup exists
- Document current certificate version
- Test certificate recovery process

#### After K3s Rebuild
- Verify certificate PVC mounted correctly
- Test Kubernetes image pull operations
- Validate external client access

---

## 📚 References

### Related Documentation
- [Harbor Registry Documentation](../README.md#harbor-container-registry)
- [K3s Certificate Management](../network-policies.md)
- [Platform Services Access](../services.md)

### Scripts & Tools
- `scripts/get-harbor-cert-from-pvc.sh` - External client certificate management
- `scripts/fix-k3s-harbor-certs.sh` - Legacy certificate distribution
- `infrastructure/cluster/roles/foundation/harbor-certs/` - Ansible role

### External Resources
- [Harbor TLS Configuration](https://goharbor.io/docs/2.0.0/install-config/configure-https/)
- [K3s Containerd Configuration](https://docs.k3s.io/advanced#configuring-containerd)
- [Docker Registry TLS](https://docs.docker.com/registry/insecure/)

---

**Last Updated:** July 2025  
**Next Review:** August 2025  
**Owner:** Platform Engineering Team