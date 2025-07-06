# K3s Calico Migration Guide

**Purpose:** Migrate from Flannel to Calico CNI for Seldon Core v2 compatibility  
**Target:** Production K3s cluster with intra-pod networking requirements  
**Status:** Ready for deployment  

## Migration Overview

### **Problem Statement**
Flannel CNI blocks intra-pod localhost connectivity required by Seldon Core v2 multi-container architecture. This migration replaces Flannel with Calico to enable proper MLServer agent-to-server communication.

### **Key Changes**
- **CNI:** Flannel VXLAN → Calico with BGP/VXLAN
- **Pod CIDR:** `10.42.0.0/16` → `10.244.0.0/16`
- **Service CIDR:** `10.43.0.0/16` → `10.96.0.0/12`
- **Firewall:** Flannel ports → Calico BGP/VXLAN ports

## Configuration Changes

### **Control Plane (`k3s_control_plane/defaults/main.yml`)**
```yaml
# K3s server arguments - Calico compatible
k3s_server_args:
  - "--write-kubeconfig-mode=644"
  - "--disable=traefik"
  - "--disable=servicelb"
  - "--disable-network-policy"      # NEW: Let Calico handle network policies
  - "--flannel-backend=none"        # CHANGED: Disable Flannel

# Network configuration - Calico standard CIDRs
k3s_cluster_cidr: "10.244.0.0/16"   # CHANGED: Calico pod network
k3s_service_cidr: "10.96.0.0/12"    # CHANGED: Standard service range

# Calico configuration
calico_enabled: true                # NEW: Enable Calico installation
calico_version: "v3.28.2"          # Latest stable version
calico_datastore: "kubernetes"      # Use K8s etcd for Calico data
calico_ipv4pool_cidr: "10.244.0.0/16"
```

### **Firewall Rules (`k3s/tasks/firewall.yml`)**
```yaml
# Calico-specific firewall rules (replacing Flannel VXLAN 8472)
- name: Allow Calico BGP (179)           # NEW: BGP routing protocol
- name: Allow Calico VXLAN (4789)        # NEW: VXLAN encapsulation  
- name: Allow Calico Typha (5473)        # NEW: Typha scaling component

# Updated network ranges
- src: "10.244.0.0/16"  # Calico pod network
- src: "10.96.0.0/12"   # Service network
```

### **Calico Installation (`k3s_control_plane/tasks/calico.yml`)**
Automated Calico deployment using Tigera operator:
1. **Wait for K3s readiness**
2. **Download Tigera operator** (latest stable)
3. **Apply Calico installation** with K3s-specific configuration
4. **Verify installation** with readiness checks

## Migration Process

### **Phase 1: Pre-Migration**
```bash
# 1. Backup current cluster state
kubectl get all -A > cluster-backup-pre-migration.yaml

# 2. Document current pod/service IPs for validation
kubectl get pods -A -o wide > pods-pre-migration.txt
kubectl get svc -A -o wide > services-pre-migration.txt

# 3. Prepare maintenance window (estimated 30-60 minutes)
```

### **Phase 2: Cluster Migration**
```bash
# 1. Run Ansible playbook (Calico enabled by default)
ansible-playbook -i inventory/production site.yml \
  --tags="k3s,calico"

# 2. Verify Calico installation
kubectl get pods -n calico-system
kubectl get installation default -o yaml

# 3. Validate networking
kubectl run test-pod --image=busybox --rm -it -- sh
# Inside pod: ping other pod IPs, test DNS resolution
```

### **Phase 3: Application Validation**
```bash
# 1. Restart Seldon Core components
kubectl rollout restart statefulset mlserver -n financial-ml

# 2. Test intra-pod connectivity
kubectl exec mlserver-0 -c agent -n financial-ml -- curl 127.0.0.1:9500/v2/health

# 3. Verify model scheduling
kubectl get model test-model-simple -n financial-ml
# Expected: READY=True

# 4. End-to-end ML inference test
curl -X POST http://[ingress]/v2/models/test-model-simple/infer -d '[test-data]'
```

## Network Configuration Details

### **Calico Features Enabled**
- **IP-in-IP/VXLAN:** Overlay networking for cross-subnet communication
- **BGP:** Direct routing where possible for performance
- **Network Policies:** Advanced Kubernetes NetworkPolicy support
- **Pod IP Management:** Automatic IP allocation and route distribution

### **K3s Integration**
- **Container Runtime:** Seamless containerd integration
- **Flexvolume Path:** Configured for K3s kubelet location
- **Auto-detection:** Automatic node interface discovery
- **Service Mesh Ready:** Compatible with Istio/other service meshes

## Rollback Plan

### **Emergency Rollback (if needed)**
```bash
# 1. Restore Flannel configuration
ansible-playbook -i inventory/production site.yml \
  --tags="k3s" \
  --extra-vars="calico_enabled=false"

# 2. Restore original CIDRs
# k3s_cluster_cidr: "10.42.0.0/16"
# k3s_service_cidr: "10.43.0.0/16"

# 3. Remove Calico components
kubectl delete installation default
kubectl delete -f tigera-operator.yaml
```

### **Rollback Triggers**
- Network connectivity failures >30 minutes
- Unable to restore pod-to-pod communication
- Critical service unavailability
- DNS resolution failures cluster-wide

## Success Criteria

### **Technical Validation**
```bash
# 1. All nodes ready with Calico
kubectl get nodes -o wide
# Expected: All nodes Ready, Calico CNI version displayed

# 2. Calico system healthy
kubectl get pods -n calico-system
# Expected: All pods Running

# 3. Intra-pod localhost connectivity
kubectl exec mlserver-0 -c agent -n financial-ml -- curl 127.0.0.1:9500
# Expected: HTTP 200 response

# 4. Model scheduling success  
kubectl get model -A
# Expected: All models READY=True

# 5. Cross-namespace communication preserved
kubectl logs seldon-scheduler-0 -n financial-ml | grep subscribe
# Expected: Successful agent subscriptions
```

### **Performance Validation**
- **Latency:** Intra-pod communication <1ms (direct localhost)
- **Throughput:** No degradation in ML inference performance  
- **Resource usage:** Calico overhead <5% additional CPU/memory

## Monitoring and Troubleshooting

### **Calico-Specific Monitoring**
```bash
# Check Calico status
calicoctl node status
calicoctl get ippool -o wide

# BGP peer status
calicoctl get bgppeer

# Network policy validation
calicoctl get networkpolicy -A
```

### **Common Issues**
1. **Node interface detection:** Verify `nodeAddressAutodetection` settings
2. **BGP connectivity:** Check firewall rules for port 179
3. **VXLAN issues:** Verify UDP port 4789 accessibility
4. **Pod IP conflicts:** Ensure no overlap with existing infrastructure

## Security Considerations

### **NetworkPolicy Enhancement**
With Calico, enable advanced network policies:
```yaml
# Example: Seldon Core namespace isolation
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: seldon-namespace-isolation
  namespace: financial-ml
spec:
  podSelector: {}
  policyTypes: [Ingress, Egress]
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: seldon-system
    - podSelector: {}
  egress:
  - to: []  # Allow all egress (can be restricted further)
```

### **Firewall Updates**
- **BGP:** Port 179/TCP for node-to-node routing
- **VXLAN:** Port 4789/UDP for overlay networking
- **Typha:** Port 5473/TCP for Calico scaling (if enabled)

## Documentation Updates

After successful migration:
1. **Update network diagrams** with new CIDR ranges
2. **Document Calico-specific troubleshooting** procedures
3. **Train operations team** on Calico management tools
4. **Update disaster recovery** procedures with Calico considerations

---

**Migration Status:** Ready for execution  
**Estimated Downtime:** 30-60 minutes  
**Risk Level:** Medium (comprehensive rollback plan available)  
**Business Impact:** Enables production Seldon Core v2 deployment