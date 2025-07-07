# MetalLB Decision Rationale

## Problem Statement

In our bare-metal K3s cluster environment, we faced significant operational challenges with NodePort services that made MetalLB adoption a practical necessity rather than just a convenience.

## The NodePort IP Address Problem

### Issue Description
- **Dynamic IP Assignment**: Worker node IP addresses were being reassigned by DHCP, causing service endpoints to change unpredictably
- **YAML Configuration Drift**: Service definitions in our YAML files quickly became outdated when node IPs changed
- **Manual Maintenance Overhead**: Constant need to update service configurations across multiple repositories when IP addresses shifted
- **Production Reliability**: Unreliable service access due to shifting infrastructure endpoints

### Example Scenario
```yaml
# Service configuration becomes invalid when node IPs change
apiVersion: v1
kind: Service
metadata:
  name: mlflow
spec:
  type: NodePort
  ports:
  - port: 5000
    nodePort: 30800
# Problem: Access via 192.168.1.85:30800 breaks when node IP changes to 192.168.1.90
```

## MetalLB as the Solution

### LoadBalancer Stability
- **Stable External IPs**: MetalLB provides consistent LoadBalancer IP addresses (192.168.1.200-250 pool)
- **DNS-Friendly**: Fixed IPs can be mapped to DNS names for stable service discovery
- **YAML Consistency**: Service configurations remain valid regardless of underlying node IP changes

### Configuration Example
```yaml
# With MetalLB - IP remains stable regardless of node changes
apiVersion: v1
kind: Service
metadata:
  name: mlflow
  annotations:
    metallb.universe.tf/loadBalancer-ips: 192.168.1.200
spec:
  type: LoadBalancer  # MetalLB assigns stable IP
  ports:
  - port: 5000
    targetPort: 5000
```

## Business Impact

### Before MetalLB (NodePort)
- ❌ **Service Interruptions**: Unpredictable downtime when node IPs changed
- ❌ **Configuration Maintenance**: Manual updates across multiple repositories
- ❌ **Team Friction**: Application teams had to track infrastructure IP changes
- ❌ **Documentation Overhead**: Constant updates to service access documentation

### After MetalLB (LoadBalancer)
- ✅ **Service Stability**: Consistent access endpoints regardless of node changes
- ✅ **Zero-Touch Operations**: No configuration updates needed for IP changes
- ✅ **Developer Experience**: Application teams use stable service endpoints
- ✅ **GitOps Compatibility**: Service definitions remain static in version control

## Implementation Decision

### Classification: **Operational Necessity**
While MetalLB started as a "nice-to-have" for cloud-like LoadBalancer functionality, it became an **operational necessity** due to:

1. **Infrastructure Instability**: DHCP-assigned node IPs in our homelab environment
2. **Maintenance Burden**: Unsustainable manual configuration updates
3. **Production Readiness**: Need for reliable service endpoints in ML workloads
4. **Team Scalability**: Reducing platform team maintenance overhead

### Alternative Approaches Considered
- **Static IP Assignment**: Not feasible in our DHCP-managed network environment
- **DNS-Based Discovery**: Still vulnerable to underlying IP changes
- **Ingress Controllers**: Added complexity for simple service exposure needs

## MetalLB Configuration Strategy

### IP Pool Design
- **Range**: 192.168.1.200-250 (dedicated LoadBalancer pool)
- **Shared IPs**: Multiple services can share the same external IP on different ports
- **Conflict Avoidance**: Pool is outside DHCP assignment range (192.168.1.1-199)

### Integration with Platform Services
- **MLflow**: Stable endpoint for model tracking and registry
- **Grafana**: Consistent monitoring dashboard access
- **ArgoCD**: Reliable GitOps management interface
- **Model Serving**: Stable endpoints for production ML inference

## Lessons Learned

1. **Infrastructure Stability Trumps Simplicity**: MetalLB's complexity is justified by operational stability
2. **DHCP Considerations**: Dynamic IP assignment in production environments requires LoadBalancer solutions
3. **GitOps Compatibility**: Static service definitions are crucial for version-controlled infrastructure
4. **Developer Experience**: Stable service endpoints improve team productivity and reduce support overhead

## Recommendation

For bare-metal Kubernetes environments with dynamic IP assignment, MetalLB should be considered a **core infrastructure component** rather than an optional add-on, especially in environments where:
- Node IP addresses are DHCP-assigned
- Multiple teams depend on stable service endpoints
- GitOps workflows require static service configurations
- Production workloads demand reliable access patterns