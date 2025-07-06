# K3s Intra-Pod Networking Issue: Localhost Connectivity Failure

**Status:** 🔴 Critical - Production Blocking  
**Created:** 2025-07-05  
**Environment:** K3s v1.32.5+k3s1 / v1.33.1+k3s1 (5 nodes)  
**Impact:** Seldon Core v2 migration blocked  

## Problem Summary

Containers within the same pod cannot communicate via localhost (127.0.0.1), preventing proper operation of multi-container pods in the Seldon Core v2 MLOps platform.

### What Works ✅
- Inter-pod communication across namespaces
- External service access
- Pod-to-service communication
- DNS resolution and service discovery

### What Fails ❌
- Intra-pod localhost connectivity (127.0.0.1 / localhost)

## Technical Details

### Pod Architecture
```
┌─────────────────────────────────────────────────────────┐
│ MLServer Pod (mlserver-0)                               │
│ ┌─────────────┐  ┌──────────────┐  ┌─────────────────┐  │
│ │   rclone    │  │    agent     │  │    mlserver     │  │
│ │   :5572     │  │              │  │ HTTP: :9000     │  │
│ │             │  │              │  │ gRPC: :9500◄────┼──┼─ FAILS HERE
│ └─────────────┘  └──────────────┘  └─────────────────┘  │
│                           │                             │
│                           └─────────────────────────────┼─ dial tcp 127.0.0.1:9500:
│                         (tries to connect)              │  connect: connection refused
└─────────────────────────────────────────────────────────┘
```

### Error Pattern
```bash
# MLServer successfully binds to all interfaces:
[mlserver.grpc] INFO - gRPC server running on http://0.0.0.0:9500

# Agent fails to connect via localhost:
level=error msg="Waiting for Inference Server service to become ready"
error="rpc error: code = Unavailable desc = connection error: desc = \"transport: Error while dialing: dial tcp 127.0.0.1:9500: connect: connection refused\""
```

## Root Cause Analysis

Based on Kubernetes networking principles, containers in the same pod **must** share network namespaces, making localhost connectivity standard behavior. The failure indicates:

1. **Container isolation misconfiguration** in containerd
2. **iptables/netfilter rules** blocking localhost traffic
3. **K3s-specific networking restrictions** (less likely)

## Diagnostic Commands

### Immediate Diagnostics
```bash
# 1. Verify network namespace sharing
kubectl exec mlserver-0 -c agent -n financial-ml -- ip addr
kubectl exec mlserver-0 -c mlserver -n financial-ml -- ip addr
# Expected: Identical loopback interface configuration

# 2. Check containerd namespace isolation
POD_ID=$(kubectl get pod mlserver-0 -n financial-ml -o jsonpath='{.status.containerStatuses[0].containerID}' | cut -d'/' -f3)
crictl inspect $POD_ID | grep -i netns
# Expected: Same netns for all containers in pod

# 3. Check for iptables rules blocking localhost
iptables -L -n -v | grep "127.0.0.1"
iptables -S | grep "127.0.0.1"
# Look for DROP rules targeting localhost traffic

# 4. Verify Flannel configuration
cat /var/lib/rancher/k3s/server/manifests/flannel.yaml | grep -A5 -B5 hairpin
```

### Advanced Diagnostics
```bash
# 5. Check containerd configuration
cat /var/lib/rancher/k3s/agent/etc/containerd/config.toml

# 6. Network troubleshooting from within pod
kubectl exec mlserver-0 -c agent -n financial-ml -- netstat -tlpn
kubectl exec mlserver-0 -c agent -n financial-ml -- ss -tlpn

# 7. Check for network security policies
kubectl get networkpolicies -A
kubectl describe networkpolicy -n financial-ml

# 8. Verify K3s cluster networking
kubectl get nodes -o wide
kubectl describe node <node-name> | grep -A10 "System Info"
```

## Attempted Solutions

### 1. NetworkPolicy Approaches ❌
```yaml
# Tried explicit permissive NetworkPolicy - No effect
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: mlserver-allow-intra-pod
spec:
  podSelector:
    matchLabels:
      seldon-server-name: mlserver
  policyTypes: [Ingress, Egress]
  ingress: [{}]  # Allow all
  egress: [{}]   # Allow all
```
**Result:** No effect (expected - NetworkPolicy doesn't affect intra-pod traffic)

### 2. MLServer Binding Configuration ❌
```yaml
# Tried different binding addresses
- name: MLSERVER_HOST
  value: "0.0.0.0"     # Default - fails
- name: MLSERVER_HOST
  value: "127.0.0.1"   # Localhost only - fails
```
**Result:** Server binds correctly but agent still can't connect

### 3. Agent Connection Configuration ❌
```yaml
# Tried different connection targets
- name: SELDON_SERVER_HOST
  value: "localhost"   # Fails
- name: SELDON_SERVER_HOST
  value: "127.0.0.1"   # Fails
- name: SELDON_SERVER_HOST
  value: "::1"         # Fails (IPv6)
```
**Result:** All localhost variants fail with "connection refused"

## Proposed Solutions

### Immediate Workaround: Pod IP Address
```yaml
# Use pod IP instead of localhost
env:
- name: SELDON_SERVER_HOST
  valueFrom:
    fieldRef:
      fieldPath: status.podIP
```
**Benefits:**
- Immediate unblocking of migration
- No platform configuration changes required
- Maintains pod-level isolation

### Emergency Workaround: Host Network
```yaml
# Last resort - use host networking
spec:
  hostNetwork: true
  dnsPolicy: ClusterFirstWithHostNet
```
**Cautions:**
- Reduces security isolation
- Port conflicts possible
- Not recommended for production

### Production Fix: iptables Rule Removal
```bash
# If iptables rules are blocking localhost traffic
iptables -L -n -v | grep "127.0.0.1"

# Remove offending rules (example)
iptables -D INPUT -s 127.0.0.1 -j DROP
iptables -D OUTPUT -d 127.0.0.1 -j DROP

# Make persistent
iptables-save > /etc/iptables/rules.v4
```

### K3s Configuration Review
```yaml
# Check K3s configuration for network restrictions
cat /etc/rancher/k3s/config.yaml

# Possible settings to verify:
disable-network-policy: true
flannel-backend: vxlan
```

## Similar Issues Resolved

### JupyterHub Success Case
Previously resolved similar intra-pod connectivity with JupyterHub by disabling NetworkPolicies:
```yaml
singleuser:
  networkPolicy:
    enabled: false
```
This suggests platform-level networking restrictions rather than application issues.

## Business Impact

**Severity:** P1 Critical
- Production Migration Blocked: Cannot complete Seldon v1→v2 upgrade
- MLOps Platform Offline: All model serving capabilities unavailable
- Timeline Impact: Enterprise migration deadline at risk

## Monitoring and Verification

### Success Criteria
```bash
# After fix, these should succeed:
kubectl exec mlserver-0 -c agent -n financial-ml -- curl localhost:9000
kubectl exec mlserver-0 -c agent -n financial-ml -- telnet localhost 9500

# Agent logs should show successful connection:
kubectl logs mlserver-0 -c agent -n financial-ml | grep "Inference Server service"
```

### Health Checks
```bash
# Verify pod health after workaround
kubectl get pods -n financial-ml -l seldon-server-name=mlserver
kubectl describe pod mlserver-0 -n financial-ml

# Check Seldon agent registration
kubectl logs mlserver-0 -c agent -n financial-ml | grep -i "registered\|capacity"
```

## Next Steps

1. **Immediate (Today):**
   - Implement Pod IP workaround to unblock migration
   - Run diagnostic commands to identify root cause
   - Document findings for future prevention

2. **Short-term (This Week):**
   - Investigate and resolve underlying networking issue
   - Test localhost connectivity restoration
   - Update documentation with permanent solution

3. **Long-term (Next Sprint):**
   - Review K3s cluster networking configuration
   - Implement monitoring for intra-pod connectivity
   - Create automated tests for platform networking health

## Related Documentation

- [Enterprise Secret Management](enterprise-secret-management-mlops.md)
- [Cross-Namespace Secrets Fix](cross-namespace-secrets-temporary-fix.md)
- [CRD Investigation Tutorial](kubectl-crd-investigation-tutorial.md)

---

**Contact:** Platform Engineering Team  
**Priority:** P1 Critical  
**Expected Resolution:** Within 24 hours using workaround, root cause analysis ongoing