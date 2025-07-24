# Standard Scoped Operator Pattern Implementation

## Overview

This document describes the **Standard Scoped Operator** (Pattern 3) implementation for Seldon Core v2.9.1. This is the officially supported pattern recommended by the Seldon team and provides a stable foundation for ML model serving.

## Architecture

```
seldon-system namespace:
├── seldon-controller-manager (clusterwide=true, watchNamespaces=[...])
├── ServerConfig resources (centralized management)
└── Core operator components

fraud-detection namespace:
├── seldon-scheduler (namespace-specific)
├── seldon-envoy (mesh proxy)
├── seldon-modelgateway
├── seldon-pipelinegateway
├── seldon-dataflow-engine
├── Server resources (reference ServerConfigs in seldon-system)
├── Model resources
└── Experiment resources
```

## Key Characteristics

### 1. **Operator Configuration**
- **Location**: `seldon-system` namespace
- **Mode**: `clusterwide=true` with `watchNamespaces` list
- **Watched Namespaces**: `fraud-detection`, `financial-inference`, `financial-mlops-pytorch`

### 2. **Runtime Deployment**
- **Full runtime stack** deployed to each watched namespace
- **Independent schedulers** per namespace (no single point of failure)
- **Isolated runtime components** for better multi-tenancy

### 3. **ServerConfig Management**
- **Centralized** in `seldon-system` namespace
- **Shared** across all watched namespaces
- **Platform-managed** for consistency

## Implementation Details

### Ansible Configuration

**File**: `infrastructure/cluster/roles/platform/seldon/defaults/main.yml`
```yaml
# Standard Scoped Operator Configuration
seldon_watch_namespaces:
  - fraud-detection
  - financial-inference
  - financial-mlops-pytorch
```

**File**: `infrastructure/cluster/roles/platform/seldon/tasks/main.yml`
```yaml
controller:
  clusterwide: true  # Must be true for watchNamespaces
  watchNamespaces: "{{ seldon_watch_namespaces | join(',') }}"
```

### Deployment Process

1. **Operator Deployment**: Controller deployed to `seldon-system`
2. **Namespace Creation**: Creates all watched namespaces with proper labels
3. **Runtime Deployment**: Deploys full runtime stack to each namespace
4. **ServerConfig Creation**: Centralized in `seldon-system`

## Usage Example

### 1. Create ServerConfig (Platform Team)
```yaml
apiVersion: mlops.seldon.io/v1alpha1
kind: ServerConfig
metadata:
  name: mlserver-config
  namespace: seldon-system
spec:
  podSpec:
    containers:
    - name: mlserver
      image: seldonio/mlserver:1.6.0
      resources:
        requests:
          memory: "1Gi"
          cpu: "500m"
```

### 2. Deploy Server (Application Team)
```yaml
apiVersion: mlops.seldon.io/v1alpha1
kind: Server
metadata:
  name: mlserver
  namespace: fraud-detection
spec:
  serverConfig: mlserver-config  # References seldon-system/mlserver-config
  replicas: 2
```

### 3. Deploy Model (Application Team)
```yaml
apiVersion: mlops.seldon.io/v1alpha1
kind: Model
metadata:
  name: fraud-model
  namespace: fraud-detection
spec:
  storageUri: "s3://models/fraud-detector/v1"
  requirements:
  - sklearn
  - xgboost
  server:
    name: mlserver
```

## Benefits

### ✅ **Official Support**
- Follows Seldon's recommended architecture
- Compatible with documentation and examples
- Guaranteed compatibility with future releases

### ✅ **Namespace Isolation**
- Each namespace has its own runtime stack
- No cross-namespace dependencies for runtime
- Independent failure domains

### ✅ **Operational Simplicity**
- Standard Kubernetes patterns
- No custom patches required
- Clear separation of concerns

### ✅ **Scalability**
- Independent schedulers prevent bottlenecks
- Namespace-level resource management
- Easy to add/remove namespaces

## Limitations

### ❌ **Centralized Configuration**
- ServerConfigs must be in `seldon-system`
- Application teams need platform team for config changes
- Less configuration autonomy

### ❌ **Resource Overhead**
- Duplicate runtime components per namespace
- Higher resource consumption
- More pods to manage

## Deployment Commands

### Initial Deployment
```bash
# Deploy Seldon with Standard Scoped Operator
ansible-playbook -i inventory/production/hosts infrastructure/cluster/site.yml --tags seldon

# Verify operator is watching namespaces
kubectl logs -n seldon-system deployment/seldon-controller-manager | grep "watching namespaces"

# Check runtime components in watched namespaces
kubectl get pods -n fraud-detection
kubectl get pods -n financial-inference
```

### Adding New Namespace
```yaml
# 1. Update inventory/production/group_vars/all.yml
seldon_watch_namespaces:
  - fraud-detection
  - financial-inference
  - financial-mlops-pytorch
  - new-ml-project  # Add new namespace

# 2. Redeploy Seldon
ansible-playbook -i inventory/production/hosts infrastructure/cluster/site.yml --tags seldon
```

## Troubleshooting

### Common Issues

1. **ServerConfig Not Found**
   - Ensure ServerConfig is in `seldon-system` namespace
   - Check RBAC permissions for cross-namespace access

2. **Runtime Components Missing**
   - Verify namespace is in `watchNamespaces` list
   - Check Helm release status: `helm list -n <namespace>`

3. **Model Deployment Fails**
   - Verify Server is running: `kubectl get servers -n <namespace>`
   - Check scheduler logs: `kubectl logs -n <namespace> seldon-scheduler-0`

## Migration from Enhanced Pattern

If migrating from Enhanced Scoped Operator:

1. **Move ServerConfigs** from application namespaces to `seldon-system`
2. **Update Server resources** (ServerConfig references work across namespaces)
3. **Deploy runtime components** to application namespaces
4. **Remove custom controller patches**

## Best Practices

1. **ServerConfig Naming**: Use descriptive names like `mlserver-gpu-large`
2. **Version Management**: Include version in ServerConfig names
3. **Resource Limits**: Always set resource requests/limits
4. **Monitoring**: Deploy Prometheus exporters in each namespace

## Conclusion

The Standard Scoped Operator pattern provides a stable, supported foundation for ML model serving with Seldon Core v2. While it requires centralized ServerConfig management, it offers namespace isolation, operational simplicity, and official support - making it the recommended approach for production deployments.

---

**Pattern**: Standard Scoped Operator (Pattern 3)  
**Seldon Version**: v2.9.1  
**Status**: Officially Supported  
**Recommended For**: Production deployments requiring stability and support