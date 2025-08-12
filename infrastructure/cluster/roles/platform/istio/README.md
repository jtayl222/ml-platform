# Istio Service Mesh Role v1.27.x

## Overview

This Ansible role deploys and configures Istio service mesh v1.27.x for the MLOps platform, providing advanced traffic management, security, and comprehensive observability features including Kiali dashboard and Jaeger distributed tracing for microservices.

## Architecture

```
istio-system namespace:
├── istiod (Control Plane v1.27.x)
├── Istio Base Components (CRDs)
├── Kiali Observability Dashboard (v1.85)
├── Jaeger Distributed Tracing
└── Webhook Configuration

istio-gateway namespace:
├── istio-gateway (Ingress Gateway)
└── Service (LoadBalancer/NodePort)

Application namespaces:
└── istio-proxy sidecars (auto-injected)
```

## Features

- **Traffic Management**: Advanced routing, load balancing, and failover
- **Security**: Automatic mTLS, RBAC, and authorization policies
- **Full Observability Stack**: 
  - Kiali v1.85 service mesh dashboard
  - Jaeger distributed tracing
  - Prometheus metrics integration
  - Grafana dashboard support
- **MetalLB Integration**: LoadBalancer support for production ingress
- **Multi-Platform Support**: Optimized configurations for K3s, Kubeadm, and EKS
- **Sidecar Injection**: Automatic or manual sidecar injection
- **Helm-Based Deployment**: Latest stable Istio charts

## Configuration

### Default Variables

```yaml
# Istio version configuration
istio_version: "1.27.0"
istio_chart_version: "1.27.0"
helm_wait_timeout: "600s"

# Namespace configuration
istio_namespace: "istio-system"
istio_gateway_namespace: "istio-gateway"

# Gateway configuration
istio_gateway_loadbalancer_ip: "192.168.1.213"
istio_gateway_http_nodeport: 30080
istio_gateway_https_nodeport: 30444

# Kiali configuration
kiali_enabled: true
kiali_version: "v1.85"
kiali_namespace: "istio-system"
kiali_nodeport: 32001
kiali_loadbalancer_ip: "192.168.1.214"
kiali_auth_strategy: "anonymous"

# Jaeger configuration
jaeger_enabled: true
jaeger_namespace: "istio-system"

# Resource limits
istio_pilot_memory_request: "128Mi"
istio_pilot_memory_limit: "1Gi"
istio_pilot_cpu_request: "100m"
istio_pilot_cpu_limit: "1000m"
istio_gateway_memory_request: "64Mi"
istio_gateway_memory_limit: "512Mi"
istio_gateway_cpu_request: "50m"
istio_gateway_cpu_limit: "500m"

# Platform-specific configurations
platform_profiles:
  k3s:
    cni:
      enabled: false
  kubeadm:
    cni:
      enabled: false
  eks:
    cni:
      enabled: true
```

### Inventory Variables

Key variables to configure in `inventory/production/group_vars/all.yml`:

```yaml
# Enable/disable Istio and observability components
enable_istio: true
kiali_enabled: true
jaeger_enabled: true

# MetalLB integration
metallb_state: present  # Enables LoadBalancer type

# Platform type (auto-detected or specify)
platform_type: "kubeadm"  # or "k3s" or "eks"

# External services integration
kiali_external_services:
  prometheus:
    url: "http://prometheus.monitoring.svc.cluster.local:9090"
  grafana:
    url: "http://grafana.monitoring.svc.cluster.local:3000"
```

## Dependencies

- Kubernetes cluster (K3s/Kubeadm/EKS) v1.29+
- MetalLB (optional, for LoadBalancer support)
- Helm 3.x
- Ansible kubernetes.core collection
- Platform detection role (for multi-platform support)

## Tasks Breakdown

1. **Helm Repositories**: Adds official Istio, Kiali, and Jaeger charts repositories
2. **Namespace Creation**: Creates istio-system namespace with proper labels
3. **Istio Base**: Deploys CRDs and base components
4. **Istiod**: Deploys control plane with telemetry v2 and tracing
5. **Gateway Deployment**: Configures ingress gateway (LoadBalancer/NodePort)
6. **Jaeger Tracing**: Deploys distributed tracing system
7. **Kiali Dashboard**: Deploys service mesh observability with external service integration
8. **Gateway Resource**: Creates default gateway for traffic management
9. **Health Verification**: Waits for all components to be ready

## Usage

### Basic Deployment

```bash
# Deploy Istio v1.27.x with full observability stack
ansible-playbook -i inventory/production/hosts infrastructure/cluster/site-multiplatform.yml --tags istio

# Deploy with MetalLB LoadBalancer (recommended)
ansible-playbook -i inventory/production/hosts infrastructure/cluster/site-multiplatform.yml --tags istio -e metallb_state=present

# Deploy only Kiali observability
ansible-playbook -i inventory/production/hosts infrastructure/cluster/site-multiplatform.yml --tags kiali

# Deploy specific platform
ansible-playbook -i inventory/production/hosts-kubeadm infrastructure/cluster/site-multiplatform.yml --tags istio -e platform_type=kubeadm
```

### Post-Deployment

1. **Verify Installation**:
   ```bash
   kubectl get pods -n istio-system
   kubectl get pods -n istio-gateway
   
   # Should see: istiod, kiali-server, jaeger-*, istio-gateway
   ```

2. **Access Observability Dashboards**:
   ```bash
   # Kiali Dashboard
   # LoadBalancer: http://192.168.1.214:20001
   # NodePort: http://<cluster-ip>:32001
   
   # Jaeger Tracing (port-forward)
   kubectl port-forward -n istio-system svc/jaeger-query 16686:16686
   # Then access: http://localhost:16686
   ```

3. **Check Gateway Service**:
   ```bash
   # LoadBalancer mode
   kubectl get svc istio-gateway -n istio-gateway
   
   # Should show EXTERNAL-IP: 192.168.1.213
   ```

4. **Verify Sidecar Injection**:
   ```bash
   # Enable injection on a namespace
   kubectl label namespace <your-namespace> istio-injection=enabled
   
   # Check namespace labels
   kubectl get namespace -L istio-injection
   
   # Restart deployments for sidecar injection
   kubectl rollout restart deployment -n <your-namespace>
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

## Observability Features

### Kiali Dashboard
- **Service Graph**: Visualize service dependencies and traffic flow
- **Health Monitoring**: Real-time service health and error rates
- **Traffic Management**: View and configure Istio routing rules
- **Security**: Monitor mTLS status and security policies
- **Tracing Integration**: Direct links to Jaeger traces

### Jaeger Tracing
- **Request Tracing**: End-to-end request flow through services
- **Performance Analysis**: Identify bottlenecks and latencies
- **Error Analysis**: Debug failed requests across services
- **Service Dependencies**: Understand service call patterns

### Prometheus Integration
- **Istio Metrics**: Automatically collected service mesh metrics
- **Custom Dashboards**: Pre-configured Grafana dashboards
- **Alerting**: Set up alerts on service mesh metrics

## Best Practices

1. **Resource Limits**: Always set appropriate resource limits for production
2. **Namespace Isolation**: Use separate namespaces for different environments
3. **mTLS Configuration**: Enable STRICT mode for production workloads
4. **Observability**: Leverage full stack - Kiali + Jaeger + Prometheus + Grafana
5. **Gateway Consolidation**: Use single gateway for multiple services
6. **Platform Optimization**: Use platform-specific profiles for optimal performance
7. **Regular Updates**: Keep Istio version current with security patches

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

- [Istio v1.27.x Documentation](https://istio.io/latest/docs/)
- [Kiali Documentation](https://kiali.io/docs/)
- [Jaeger Documentation](https://www.jaegertracing.io/docs/)
- [Istio Best Practices](https://istio.io/latest/docs/ops/best-practices/)
- [Istio Security](https://istio.io/latest/docs/concepts/security/)

---

**Role Version**: 2.0.0  
**Istio Version**: v1.27.x (Helm-based)  
**Kiali Version**: v1.85  
**Jaeger Version**: 1.54  
**Multi-Platform**: K3s, Kubeadm, EKS  
**Maintained By**: Platform Team