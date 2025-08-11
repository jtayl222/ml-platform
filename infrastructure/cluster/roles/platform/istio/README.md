# Istio Service Mesh Role

## Overview

This Ansible role deploys and configures Istio service mesh for the MLOps platform, providing advanced traffic management, security, and observability features for microservices.

## Architecture

```
istio-system namespace:
├── istiod (Control Plane)
├── Istio Base Components
└── Webhook Configuration

istio-gateway namespace:
├── istio-gateway (Ingress Gateway)
└── HPA Configuration

Application namespaces:
└── istio-proxy sidecars (auto-injected)
```

## Features

- **Traffic Management**: Advanced routing, load balancing, and failover
- **Security**: Automatic mTLS, RBAC, and security policies
- **Observability**: Distributed tracing, metrics, and logging
- **MetalLB Integration**: LoadBalancer support for production ingress
- **Sidecar Injection**: Automatic or manual sidecar injection

## Configuration

### Default Variables

```yaml
# Namespace configuration
istio_namespace: "istio-system"
istio_gateway_namespace: "istio-gateway"

# Gateway configuration
istio_gateway_loadbalancer_ip: "192.168.1.240"
istio_gateway_http_nodeport: 31080
istio_gateway_https_nodeport: 31443

# Resource limits
istio_pilot_memory_request: "512Mi"
istio_pilot_memory_limit: "1Gi"
istio_gateway_memory_request: "256Mi"
istio_gateway_memory_limit: "512Mi"

# Sidecar injection namespaces
istio_injection_namespaces:
  - fraud-detection
  - financial-inference
  - financial-mlops-pytorch
```

### Inventory Variables

Key variables to configure in `inventory/production/group_vars/all.yml`:

```yaml
# Enable/disable Istio
enable_istio: true

# MetalLB integration
metallb_state: present  # Enables LoadBalancer type

# Custom injection namespaces
istio_injection_namespaces:
  - your-app-namespace
```

## Dependencies

- Kubernetes cluster (K3s/K8s)
- MetalLB (optional, for LoadBalancer support)
- Helm 3.x

## Tasks Breakdown

1. **Helm Repository**: Adds official Istio charts repository
2. **Namespace Creation**: Creates istio-system namespace
3. **Istio Base**: Deploys CRDs and base components
4. **Istiod**: Deploys control plane
5. **Gateway Deployment**: Configures ingress gateway (LoadBalancer/NodePort)
6. **Sidecar Injection**: Labels namespaces for automatic injection
7. **Health Verification**: Waits for components to be ready

## Usage

### Basic Deployment

```bash
# Deploy Istio with default settings
ansible-playbook -i inventory/production/hosts infrastructure/cluster/site.yml --tags istio

# Deploy with MetalLB LoadBalancer
ansible-playbook -i inventory/production/hosts infrastructure/cluster/site.yml --tags istio -e metallb_state=present
```

### Post-Deployment

1. **Verify Installation**:
   ```bash
   kubectl get pods -n istio-system
   kubectl get pods -n istio-gateway
   ```

2. **Check Gateway Service**:
   ```bash
   # LoadBalancer mode
   kubectl get svc istio-gateway -n istio-gateway
   
   # Should show EXTERNAL-IP: 192.168.1.240
   ```

3. **Verify Sidecar Injection**:
   ```bash
   # Check namespace labels
   kubectl get namespace -L istio-injection
   
   # Restart deployments for sidecar injection
   kubectl rollout restart deployment -n fraud-detection
   ```

## Gateway Configuration

### Create Gateway Resource

```yaml
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: ml-gateway
  namespace: istio-system
spec:
  selector:
    istio: ingressgateway
  servers:
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - "*.local"
```

### Create VirtualService

```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: ml-routing
  namespace: fraud-detection
spec:
  hosts:
  - "fraud-api.local"
  gateways:
  - istio-system/ml-gateway
  http:
  - match:
    - uri:
        prefix: /v1/
    route:
    - destination:
        host: fraud-service
        port:
          number: 8080
```

## Network Policy Considerations

When using Istio with network policies:

1. **Label istio-system namespace**:
   ```bash
   kubectl label namespace istio-system name=istio-system
   ```

2. **Allow istiod communication** (port 15012):
   ```yaml
   egress:
   - to:
     - namespaceSelector:
         matchLabels:
           name: istio-system
     ports:
     - protocol: TCP
       port: 15012
   ```

## Troubleshooting

### Common Issues

1. **Sidecar Not Injected**
   - Check namespace label: `kubectl get ns <namespace> --show-labels`
   - Restart deployment: `kubectl rollout restart deployment -n <namespace>`

2. **503 Service Unavailable**
   - Verify sidecar is running: `kubectl get pod <pod> -o yaml | grep istio-proxy`
   - Check pod has 2/2 containers ready

3. **Connection Refused to istiod**
   - Check network policies allow port 15012
   - Verify istio-system namespace labels

4. **PodSecurity Violations**
   - For privileged operations: `kubectl label ns <namespace> pod-security.kubernetes.io/enforce=privileged`

### Debug Commands

```bash
# Check Istio version
kubectl get deploy -n istio-system istiod -o yaml | grep image:

# View gateway logs
kubectl logs -n istio-gateway deployment/istio-gateway

# Check sidecar injection webhook
kubectl get mutatingwebhookconfigurations

# Test connectivity from sidecar
kubectl exec <pod> -c istio-proxy -- curl -v istiod.istio-system:15012
```

## Best Practices

1. **Resource Limits**: Always set appropriate resource limits
2. **Namespace Isolation**: Use separate namespaces for workloads
3. **mTLS**: Enable STRICT mode for production
4. **Observability**: Deploy Kiali, Jaeger, and Grafana
5. **Gateway Consolidation**: Use single gateway for multiple services

## Integration with ML Platform

### Seldon Core Integration
- Seldon models automatically get Istio sidecars
- Enables advanced traffic management for A/B testing
- Provides mTLS between model services

### Benefits for MLOps
- **Canary Deployments**: Gradual model rollouts
- **Traffic Splitting**: A/B testing for models
- **Security**: Encrypted model inference traffic
- **Observability**: Request tracing through model pipeline

## Security Considerations

1. **mTLS by Default**: All pod-to-pod communication encrypted
2. **RBAC**: Define authorization policies for services
3. **Gateway Security**: TLS termination at ingress
4. **Network Policies**: Additional layer with Istio policies

## Monitoring

Recommended dashboards:
- Istio Control Plane Dashboard
- Istio Mesh Dashboard
- Istio Service Dashboard
- Istio Workload Dashboard

## References

- [Istio Documentation](https://istio.io/latest/docs/)
- [Istio Best Practices](https://istio.io/latest/docs/ops/best-practices/)
- [Istio Security](https://istio.io/latest/docs/concepts/security/)

---

**Role Version**: 1.0.0  
**Istio Version**: Latest stable (via Helm)  
**Maintained By**: Platform Team