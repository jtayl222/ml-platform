# CNI Migration: Calico to Cilium

## Overview

This document describes the migration from Calico to Cilium CNI due to a critical networking issue with Calico's ARP resolution for the 169.254.1.1 gateway.

## Problem Statement

**Issue**: Calico CNI has a known bug where pods cannot resolve ARP requests to the link-local gateway (169.254.1.1), preventing all pod-to-service and pod-to-external connectivity.

**GitHub Issues**:
- [Issue #8689](https://github.com/projectcalico/calico/issues/8689): "Newly created Pod doesn't get ARP response for 169.254.1.1 for 1 minute then succeeds"
- [Issue #4186](https://github.com/projectcalico/calico/issues/4186): "ping failed to calico gateway for only some of pods"

**Impact**: 
- ❌ Complete pod networking failure
- ❌ Argo Workflows cannot communicate with API server
- ❌ Model serving workloads blocked
- ❌ MLOps pipelines non-functional

## Solution: Cilium CNI

**Why Cilium**:
- ✅ No known 169.254.1.1 ARP issues
- ✅ Excellent K3s compatibility
- ✅ Network policies support (required for Seldon Core v2)
- ✅ Production-grade reliability and performance
- ✅ Advanced observability with Hubble

## Migration Process

### Prerequisites

1. **Backup Current State**
   ```bash
   kubectl get nodes -o yaml > k3s-nodes-backup.yaml
   kubectl get pods --all-namespaces -o yaml > pods-backup.yaml
   ```

2. **Ensure Kubeconfig Access**
   ```bash
   export KUBECONFIG=/tmp/k3s-kubeconfig.yaml
   kubectl get nodes  # Verify connectivity
   ```

### Automated Migration

Run the migration playbook:

```bash
ansible-playbook -i inventory/production/hosts infrastructure/cluster/migrate-to-cilium.yml
```

**Expected Timeline**:
- **Calico removal**: 1-2 minutes
- **Cilium installation**: 2-3 minutes  
- **Network stabilization**: 1-2 minutes
- **Total downtime**: 4-7 minutes

### Manual Migration Steps

If automation fails, follow these manual steps:

1. **Remove Calico**
   ```bash
   kubectl delete installation default
   kubectl delete ippool default-ipv4-ippool
   kubectl delete -n tigera-operator deployment tigera-operator
   ```

2. **Install Cilium**
   ```bash
   helm repo add cilium https://helm.cilium.io/
   helm install cilium cilium/cilium --namespace kube-system \
     --set kubeProxyReplacement=true \
     --set k8sServiceHost=192.168.1.85 \
     --set k8sServicePort=6443 \
     --set routingMode=vxlan \
     --set ipam.mode=cluster-pool \
     --set ipam.operator.clusterPoolIPv4PodCIDRList=10.42.0.0/16
   ```

3. **Verify Installation**
   ```bash
   kubectl get pods -n kube-system -l k8s-app=cilium
   kubectl get nodes  # Should show Ready
   ```

### Post-Migration Validation

1. **Test Pod Connectivity**
   ```bash
   kubectl run test --image=nicolaka/netshoot --rm -it -- ping -c 3 8.8.8.8
   kubectl run test --image=nicolaka/netshoot --rm -it -- curl -k https://10.43.0.1:443/healthz
   ```

2. **Verify DNS Resolution**
   ```bash
   kubectl run test --image=nicolaka/netshoot --rm -it -- nslookup kubernetes.default.svc.cluster.local
   ```

3. **Check Network Policies**
   ```bash
   kubectl get networkpolicies --all-namespaces
   ```

## Cilium Configuration

### Default Configuration
- **Routing Mode**: VXLAN (for compatibility)
- **IPAM**: Cluster Pool (10.42.0.0/16)
- **Kube-proxy Replacement**: Enabled
- **Network Policies**: Enabled (Kubernetes + Cilium)
- **Hubble Observability**: Enabled

### Advanced Features Available
- **BGP Support**: Available if needed
- **WireGuard Encryption**: Can be enabled
- **Service Mesh**: Built-in service mesh capabilities
- **Load Balancing**: Advanced load balancing algorithms

## Troubleshooting

### Common Issues

1. **Cilium Pods CrashLooping**
   ```bash
   kubectl logs -n kube-system -l k8s-app=cilium
   # Check for configuration errors
   ```

2. **Connectivity Still Failing**
   ```bash
   # Verify Cilium status
   kubectl exec -n kube-system ds/cilium -- cilium status
   
   # Check connectivity test
   kubectl apply -f https://raw.githubusercontent.com/cilium/cilium/HEAD/examples/kubernetes/connectivity-check/connectivity-check.yaml
   ```

3. **Network Policies Not Working**
   ```bash
   # Verify policy enforcement
   kubectl exec -n kube-system ds/cilium -- cilium endpoint list
   ```

### Rollback Plan

If migration fails, quickly rollback to Calico:

```bash
# Remove Cilium
helm uninstall cilium -n kube-system

# Reinstall Calico
ansible-playbook -i inventory/production/hosts infrastructure/cluster/site.yml --tags calico
```

## Integration with Existing Stack

### Seldon Core v2 Compatibility
- ✅ **Network Policies**: Cilium supports both Kubernetes and Cilium Network Policies
- ✅ **Service Mesh**: Native service mesh features complement Seldon
- ✅ **Observability**: Hubble provides detailed network visibility

### MetalLB Integration
- ✅ **LoadBalancer Services**: Cilium works seamlessly with MetalLB
- ✅ **BGP Advertisement**: Can coexist with Cilium BGP if needed

### Monitoring Integration
- ✅ **Prometheus Metrics**: Cilium exposes comprehensive metrics
- ✅ **Grafana Dashboards**: Pre-built dashboards available
- ✅ **Hubble UI**: Web-based network observability

## Maintenance

### Regular Tasks
1. **Monitor Cilium Health**
   ```bash
   kubectl exec -n kube-system ds/cilium -- cilium status
   ```

2. **Update Cilium**
   ```bash
   helm upgrade cilium cilium/cilium -n kube-system
   ```

3. **Check Connectivity**
   ```bash
   kubectl apply -f cilium-connectivity-check.yaml
   ```

### Backup Configuration
```bash
helm get values cilium -n kube-system > cilium-values-backup.yaml
kubectl get ciliumnetworkpolicies --all-namespaces -o yaml > cilium-policies-backup.yaml
```

## References

- [Cilium Documentation](https://docs.cilium.io/)
- [K3s CNI Guide](https://docs.k3s.io/networking/basic-network-options)
- [Calico Issues](https://github.com/projectcalico/calico/issues/)
- [Network Policy Recipes](https://github.com/ahmetb/kubernetes-network-policy-recipes)