# Network Policy Management

This document outlines the recommended approach for managing network policies in the ML platform, following industry best practices for separation of concerns between platform and application teams.

## Responsibility Matrix

### Platform Team Manages

- **Cluster-wide policies**: DNS resolution, service mesh configuration
- **Cross-namespace communication**: Baseline connectivity between platform services
- **Infrastructure security**: CNI configuration, MetalLB integration
- **Namespace lifecycle**: Creation, labeling, baseline network policies
- **Security baselines**: Default deny rules, compliance frameworks

### Application Team Manages  

- **Application-specific policies**: Service-to-service communication within namespaces
- **Business logic security**: Model access patterns, data flow restrictions
- **External service access**: Model downloads, telemetry endpoints
- **Intra-namespace rules**: Fine-grained application security

## Implementation Architecture

### Platform Baseline (Ansible Managed)

The platform creates baseline network policies via Ansible automation:

```yaml
# Applied by: infrastructure/cluster/roles/platform/seldon/tasks/main.yml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: "{{ namespace }}-baseline"
  namespace: "{{ namespace }}"
spec:
  podSelector: {}
  policyTypes: [Ingress, Egress]
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: seldon-system
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          name: seldon-system
  - to:
    - namespaceSelector:
        matchLabels:
          name: kube-system
    ports:
    - protocol: UDP
      port: 53
    - protocol: TCP  
      port: 53
```

### Application Enhancement (Application Managed)

Application teams add specific requirements on top of the baseline:

```yaml
# Example: financial-mlops-pytorch/k8s/base/network-policy.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: financial-ml-isolation
  namespace: financial-ml
spec:
  podSelector: {}
  policyTypes: [Ingress, Egress]
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: seldon-system
  - from:
    - namespaceSelector:
        matchLabels:
          name: financial-ml
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          name: seldon-system
  - to:
    - namespaceSelector:
        matchLabels:
          name: financial-ml
  - to:
    - namespaceSelector:
        matchLabels:
          name: kube-system
    ports:
    - protocol: UDP
      port: 53
    - protocol: TCP
      port: 53
  # Application-specific: External model downloads and telemetry
  - to: []
    ports:
    - protocol: TCP
      port: 443
    - protocol: TCP
      port: 80
    - protocol: TCP
      port: 4317  # OpenTelemetry
    - protocol: TCP
      port: 4318  # OpenTelemetry
```

## Deployment Workflow

### 1. Platform Team: Create Namespace Infrastructure

```bash
# Add namespace to platform configuration
# Edit: inventory/production/group_vars/all.yml
seldon_ml_namespaces:
  - financial-ml
  - new-ml-project

# Deploy platform baseline
ansible-playbook -i inventory/production/hosts infrastructure/cluster/site.yml --tags seldon
```

### 2. Application Team: Deploy Application-Specific Policies

```bash
# Deploy application enhancements
kubectl apply -f k8s/base/network-policy.yaml -n financial-ml
```

## Policy Templates

### Standard ML Namespace Policy

For teams following the reference implementation:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: ml-isolation
  namespace: ${NAMESPACE}
spec:
  podSelector: {}
  policyTypes: [Ingress, Egress]
  ingress:
  # Platform services
  - from:
    - namespaceSelector:
        matchLabels:
          name: seldon-system
  # Intra-namespace communication
  - from:
    - namespaceSelector:
        matchLabels:
          name: ${NAMESPACE}
  egress:
  # Platform services
  - to:
    - namespaceSelector:
        matchLabels:
          name: seldon-system
  # Intra-namespace communication
  - to:
    - namespaceSelector:
        matchLabels:
          name: ${NAMESPACE}
  # DNS resolution (CRITICAL)
  - to:
    - namespaceSelector:
        matchLabels:
          name: kube-system
    ports:
    - protocol: UDP
      port: 53
    - protocol: TCP
      port: 53
  # External access (customize as needed)
  - to: []
    ports:
    - protocol: TCP
      port: 443  # HTTPS
    - protocol: TCP
      port: 80   # HTTP
```

## Security Considerations

### Defense in Depth

1. **Platform Layer**: Provides secure foundation and infrastructure connectivity
2. **Application Layer**: Adds business-specific security requirements
3. **Service Mesh**: Additional mTLS and traffic management (if using Istio)

### Critical Requirements

- **DNS Resolution**: Always allow port 53 to kube-system namespace
- **Seldon Integration**: Allow communication with seldon-system namespace
- **Monitoring**: Consider telemetry ports (4317/4318) for observability

### Common Patterns

```yaml
# Cross-namespace communication (between related applications)
- from:
  - namespaceSelector:
      matchLabels:
        team: financial-ml
        
# Database access (specific services)
- to:
  - namespaceSelector:
      matchLabels:
        name: database
  ports:
  - protocol: TCP
    port: 5432

# Model artifact storage
- to: []
  ports:
  - protocol: TCP
    port: 9000  # MinIO/S3
```

## Troubleshooting

### DNS Resolution Issues

```bash
# Test DNS from pod
kubectl exec -n financial-ml <pod> -- nslookup kubernetes.default.svc.cluster.local

# Check network policy
kubectl describe networkpolicy -n financial-ml
```

### Cross-Namespace Communication

```bash
# Verify namespace labels
kubectl get namespaces --show-labels

# Test connectivity
kubectl exec -n financial-ml <pod> -- curl http://service.seldon-system.svc.cluster.local
```

### Policy Conflicts

Network policies are **additive** - multiple policies in the same namespace are combined. Ensure no conflicting rules exist.

## Migration from Legacy Systems

When migrating from Flannel to Calico (as done in this platform):

1. **Platform team**: Updates CNI and baseline policies
2. **Application teams**: No action required if following templates
3. **Validation**: Test DNS and cross-namespace connectivity

## Best Practices Summary

✅ **Do:**
- Use namespace labels for selector matching
- Always allow DNS resolution to kube-system
- Start with restrictive policies and add permissions as needed
- Document external service requirements
- Test policies in development first

❌ **Don't:**
- Create policies that block platform infrastructure
- Use pod selectors without namespace context
- Allow broad external access without justification
- Modify platform-managed baseline policies
- Deploy without testing DNS connectivity