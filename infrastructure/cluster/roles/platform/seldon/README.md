# Seldon Core Platform Role

Deploy Seldon Core v2 for ML model serving with custom image support.

## Features

- **Model Serving**: Deploy ML models as microservices
- **Multi-framework Support**: Scikit-Learn, MLflow, TensorFlow, PyTorch
- **Auto-scaling**: Kubernetes-native scaling (when KEDA enabled)
- **A/B Testing**: Advanced deployment strategies
- **Monitoring**: Prometheus metrics integration
- **Network Security**: Automatic network policies for ML namespaces

## Overview

This role deploys Seldon Core v2 with support for:
- Production model serving with Istio integration
- Custom agent images for testing unreleased features
- MetalLB LoadBalancer integration
- PR testing capabilities (e.g., PR #6582)

## Variables

### Required Variables
- `seldon_namespace`: Kubernetes namespace (default: "seldon-system")  
- `seldon_operator_image_tag`: Seldon Core version (default: "2.9.0")

### Optional Variables
- `seldon_usage_metrics`: Enable usage metrics (default: true)
- `seldon_istio_enabled`: Enable Istio integration (default: true)
- `seldon_enable_loadbalancer`: Enable MetalLB LoadBalancer service (default: true)
- `seldon_enable_network_policies`: Apply network policies to ML namespaces (default: true)
- `seldon_ml_namespaces`: List of ML namespaces to secure (default: ["financial-ml"])

### Custom Image Variables

```yaml
# Enable custom agent images
seldon_custom_images:
  enabled: true
  registry: "your-registry.com"
  agent:
    repository: "your-org/seldon-agent"  
    tag: "custom-version"
    pullPolicy: "Always"

# PR #6582 - SELDON_SERVER_HOST support
seldon_server_host:
  enabled: true
  value: "localhost"  # or your inference service host

# Additional environment variables for agent
seldon_agent_env_vars:
  - name: "CUSTOM_SETTING"
    value: "custom_value"
  - name: "SELDON_LOG_LEVEL"
    value: "debug"
```

### Network Policy Variables

```yaml
# Network security configuration
seldon_enable_network_policies: true
seldon_allow_external_telemetry: true
seldon_ml_namespaces:
  - financial-ml
  - iris-demo
  - another-ml-project
```

## Usage Examples

### Standard Production Deployment
```yaml
# inventory/production/group_vars/all.yml
seldon_namespace: "seldon-system"
seldon_operator_image_tag: "2.9.0"
seldon_istio_enabled: true
seldon_enable_loadbalancer: true
seldon_enable_network_policies: true
seldon_ml_namespaces:
  - financial-ml
```

### Testing Environment with Custom Images
```yaml
# inventory/testing/group_vars/all.yml
seldon_custom_images:
  enabled: true
  registry: "docker.io/library"  # k3s import path
  agent:
    repository: "seldon-agent"
    tag: "pr6582-test"
    pullPolicy: "Never"  # Use local image

seldon_server_host:
  enabled: true
  value: "localhost"

seldon_agent_env_vars:
  - name: "SELDON_LOG_LEVEL"
    value: "debug"
```

## Testing PR Changes

For testing unreleased Seldon features:

### 1. Build Custom Image
```bash
# On build machine
docker build -f scheduler/Dockerfile.agent -t seldon-agent:pr6582 .
```

### 2. Transfer to K3s Cluster
```bash
# Transfer to k3s node
docker save seldon-agent:pr6582 | gzip > /tmp/seldon-agent.tar.gz
scp /tmp/seldon-agent.tar.gz user@k3s-node:/tmp/
ssh user@k3s-node "sudo k3s ctr image import /tmp/seldon-agent.tar.gz"
```

### 3. Configure Inventory
```yaml
# inventory/testing/group_vars/all.yml
seldon_custom_images:
  enabled: true
  registry: "docker.io/library"
  agent:
    repository: "seldon-agent"
    tag: "pr6582"
    pullPolicy: "Never"
```

### 4. Deploy
```bash
# Full deployment
ansible-playbook -i inventory/testing infrastructure/cluster/site.yml --tags seldon

# Deploy only custom configuration
ansible-playbook -i inventory/testing infrastructure/cluster/site.yml --tags seldon-custom
```

## Deployment Commands

```bash
# Standard deployment
ansible-playbook -i inventory/production/hosts infrastructure/cluster/site.yml --tags seldon

# With custom images enabled
ansible-playbook -i inventory/testing/hosts infrastructure/cluster/site.yml --tags seldon -e seldon_custom_images.enabled=true

# Redeploy after image changes
kubectl delete pods -n seldon-system -l app=mlserver
ansible-playbook -i inventory/testing/hosts infrastructure/cluster/site.yml --tags seldon-custom
```

## Verification

```bash
# Check Seldon pods
kubectl get pods -n seldon-system

# Check custom ServerConfig
kubectl get serverconfig -n seldon-system

# Check agent image
kubectl describe pod -n seldon-system mlserver-0 | grep Image

# Test model deployment
kubectl apply -f examples/iris-model.yaml
```

## Benefits

1. **Backwards Compatible**: Default behavior unchanged
2. **Environment Specific**: Different configs for test/prod
3. **Version Controlled**: All changes tracked in git
4. **Repeatable**: Consistent deployments across environments  
5. **Rollback Friendly**: Easy to disable custom images
6. **Team Friendly**: Clear documentation and examples

## Network Policy Configuration

This role automatically configures network policies for ML namespaces to ensure secure communication after Calico CNI migration. The network policies:

- **Allow intra-namespace communication**: Pods within the same ML namespace can communicate
- **Allow communication with seldon-system**: ML pods can access Seldon Core services
- **Allow DNS resolution**: Pods can resolve service names via CoreDNS in kube-system
- **Allow external access**: HTTPS/HTTP for model downloads and external telemetry

### Network Policy Template

The role creates network policies that resolve DNS timeout issues commonly seen after CNI migrations:

```yaml
# Example network policy created for financial-ml namespace
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: financial-ml-isolation
  namespace: financial-ml
spec:
  podSelector: {}
  policyTypes: [Ingress, Egress]
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          name: kube-system
    ports:
    - protocol: UDP
      port: 53  # DNS resolution
```

### Troubleshooting

If you see DNS timeout errors like:
```
lookup seldon-scheduler on 10.43.0.10:53: dial udp 10.43.0.10:53: i/o timeout
```

This indicates network policies are blocking DNS traffic. The role automatically fixes this by:
1. Labeling kube-system namespace with `name=kube-system`
2. Creating network policies that allow DNS egress
3. Allowing required communication between ML and Seldon namespaces

## Tags

- `seldon`: All Seldon Core tasks
- `seldon-custom`: Custom image configuration only
- `network-policy`: Network policy tasks only
- `platform`: Platform-level tasks
- `metallb`: MetalLB LoadBalancer tasks