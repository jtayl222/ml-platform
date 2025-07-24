# Seldon Core v2.9.1 Known Issues

## Critical Bug: ServerConfig Namespace Lookup Issue

### Summary
**CRITICAL**: Seldon Core v2.9.1 controller hardcodes ServerConfig namespace lookup, preventing proper multi-tenant deployments where ServerConfig and Server resources are in application namespaces.

### Root Cause Analysis
The `GetServerConfigForServer` function in the Seldon controller hardcodes namespace lookup to `constants.SeldonNamespace` instead of looking in the Server resource's namespace:

```go
// BUG: Hardcoded namespace lookup in serverconfig_types.go:77
err := client.Get(context.TODO(), types.NamespacedName{
    Name: serverConfig, 
    Namespace: constants.SeldonNamespace  // Should be server.Namespace
}, &sc)
```

Where `constants.SeldonNamespace` defaults to `"seldon-mesh"` (or `POD_NAMESPACE` environment variable).

### Impact
- **Namespace Isolation Broken**: Cannot deploy ServerConfig in application namespaces
- **Multi-Tenant Platform Blocked**: Each team cannot have isolated ServerConfig resources
- **Pod Creation Failures**: StatefulSets created with empty container images
- **Complete Deployment Failure**: Pods fail validation due to missing required image fields

### What Actually Happens
1. ✅ Controller receives Server resource in application namespace (e.g., `financial-mlops-pytorch`)
2. ❌ Controller looks for ServerConfig in wrong namespace (`seldon-system` instead of `financial-mlops-pytorch`)
3. ❌ ServerConfig lookup fails silently - returns empty/default ServerConfig
4. ❌ Empty PodSpec passed to StatefulSet generation - no container images specified
5. ❌ StatefulSet created with missing image fields: `spec.containers[].image: Required value`
6. ❌ Pod creation fails validation

### Error Symptoms
```bash
# StatefulSet exists but pods don't start
kubectl get statefulset -n financial-mlops-pytorch
NAME       READY   AGE
mlserver   0/1     10m

# Pod creation failures
kubectl get events -n financial-mlops-pytorch
Warning  FailedCreate  statefulset-controller  
create Pod mlserver-0 failed: Pod "mlserver-0" is invalid: 
[spec.containers[0].image: Required value, spec.containers[1].image: Required value]

# StatefulSet shows empty images
kubectl describe statefulset mlserver -n financial-mlops-pytorch
Containers:
  agent:
    Image:      <-- EMPTY
  mlserver:
    Image:      <-- EMPTY
```

### Workarounds

#### Option 1: Deploy to seldon-system namespace (Recommended)
Deploy both ServerConfig and Server resources to the same namespace as the Seldon controller:

```yaml
apiVersion: mlops.seldon.io/v1alpha1
kind: ServerConfig
metadata:
  name: mlserver-config
  namespace: seldon-system  # Same as controller
spec:
  podSpec:
    containers:
    - name: agent
      image: seldonio/seldon-agent:2.9.1
    - name: mlserver
      image: seldonio/mlserver:1.6.0
---
apiVersion: mlops.seldon.io/v1alpha1
kind: Server
metadata:
  name: mlserver
  namespace: seldon-system  # Same as controller
spec:
  serverConfig: mlserver-config
```

#### Option 2: Check POD_NAMESPACE environment
Verify which namespace the controller expects:
```bash
kubectl get pod -n seldon-system -l app.kubernetes.io/name=seldon-v2-controller-manager -o yaml | grep POD_NAMESPACE
```

### Proper Fix Required
The controller needs to be patched to look for ServerConfig in the same namespace as the Server resource:

```go
// Current (broken):
func GetServerConfigForServer(serverConfig string, client client.Client) (*ServerConfig, error) {
    err := client.Get(context.TODO(), types.NamespacedName{
        Name: serverConfig, 
        Namespace: constants.SeldonNamespace  // HARDCODED
    }, &sc)
}

// Should be:
func GetServerConfigForServer(serverConfig string, namespace string, client client.Client) (*ServerConfig, error) {
    err := client.Get(context.TODO(), types.NamespacedName{
        Name: serverConfig, 
        Namespace: namespace  // USE PROVIDED NAMESPACE
    }, &sc)
}
```

### Related Issues
- **Namespace Watching**: When `clusterwide: false`, controller only watches its own namespace (separate bug)
- **Certificate Persistence**: Harbor certificate management across K3s rebuilds (resolved)
- **Network Policies**: Application namespace connectivity to Harbor and Seldon (resolved)

### Platform Impact
This bug fundamentally breaks the multi-tenant MLOps platform architecture where:
- Each development team has their own namespace
- Teams deploy custom ServerConfig with specific image versions
- Platform maintains namespace isolation for security

**Status**: Blocking issue for production multi-tenant deployments. Bug reports submitted to Seldon team.

### Version Information
- **Affected Version**: Seldon Core v2.9.1
- **Controller Mode**: Both `clusterwide: true` and `clusterwide: false`
- **Helm Charts**: All v2.9.1 charts affected
- **Workaround Available**: Yes (deploy to seldon-system namespace)
- **Timeline**: Waiting for Seldon Core v2.9.2 or hotfix