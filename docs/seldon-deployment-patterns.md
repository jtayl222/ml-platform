# Seldon Core v2.9.1 Deployment Patterns & Migration Paths

## Overview
This document describes the different Seldon deployment patterns, the issues encountered with the Scoped Operator Pattern in v2.9.1, and the migration paths between patterns.

## Deployment Pattern Comparison

### Pattern 1: Scoped Operator Pattern (Original Goal)
**Architecture**: Multi-namespace isolation with namespace-scoped ServerConfig lookup
```
┌─────────────────────────────────────────────────────────────┐
│ seldon-system namespace                                     │
│ ├── seldon-v2-controller-manager (watches all namespaces)  │
│ ├── seldon-scheduler                                        │
│ └── Core Seldon components                                  │
└─────────────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────────────┐
│ financial-mlops-pytorch namespace                          │
│ ├── ServerConfig: mlserver-config (team-specific)          │
│ ├── Server: mlserver (references local ServerConfig)       │
│ ├── Models: baseline-predictor, enhanced-predictor         │
│ └── Experiments: financial-ab-test-experiment              │
└─────────────────────────────────────────────────────────────┘
```

**Benefits**:
- ✅ True multi-tenancy with namespace isolation
- ✅ Teams manage their own ServerConfig with custom images
- ✅ Network policies enforce security boundaries
- ✅ Clean separation of platform vs application concerns

**Status**: **BLOCKED** by Seldon Core v2.9.1 namespace lookup bug

### Pattern 2: Single Namespace Pattern (Current Workaround)
**Architecture**: Everything deployed in seldon-system namespace
```
┌─────────────────────────────────────────────────────────────┐
│ seldon-system namespace                                     │
│ ├── seldon-v2-controller-manager                           │
│ ├── seldon-scheduler                                        │
│ ├── Core Seldon components                                  │
│ ├── ServerConfig: mlserver-config (shared)                 │
│ ├── Server: mlserver                                        │
│ ├── Models: baseline-predictor, enhanced-predictor         │
│ └── Experiments: financial-ab-test-experiment              │
└─────────────────────────────────────────────────────────────┘
```

**Benefits**:
- ✅ Works with Seldon Core v2.9.1 (no namespace lookup bug)
- ✅ All features functional immediately
- ✅ No controller patching required

**Drawbacks**:
- ❌ No namespace isolation between teams
- ❌ All teams deploy to same namespace (security/management issues)
- ❌ Shared ServerConfig resources (potential conflicts)

## Migration History

### Phase 1: Original Scoped Operator Attempt
**Configuration Applied**:
```yaml
# In infrastructure/cluster/roles/platform/seldon/tasks/main.yml
controller:
  clusterwide: false
  watchNamespaces: ["financial-mlops-pytorch", "financial-inference"]
```

**Issues Encountered**:
1. **Namespace Watching Bug**: Controller ignored `watchNamespaces` with `clusterwide: false`
2. **ServerConfig Lookup Bug**: Controller hardcoded namespace lookup to `seldon-system`

**Symptoms**:
- Controller only processed resources in `seldon-system` namespace
- ServerConfig lookup failed silently in application namespaces
- StatefulSets created with empty container images
- Pod creation failures: `spec.containers[].image: Required value`

### Phase 2: Cluster-Wide Controller Attempt
**Configuration Applied**:
```yaml
# In infrastructure/cluster/roles/platform/seldon/tasks/main.yml
controller:
  clusterwide: true
  # Removed watchNamespaces parameter
```

**Results**:
- ✅ Controller now watches all namespaces
- ❌ Still fails ServerConfig lookup in application namespaces
- ❌ Same pod creation failures due to namespace lookup bug

### Phase 3: Single Namespace Workaround (Current)
**Action Taken**: Moved all resources to `seldon-system` namespace

**Resources Relocated**:
```bash
# From financial-mlops-pytorch namespace to seldon-system namespace
- ServerConfig: mlserver-config
- Server: mlserver  
- Models: baseline-predictor, enhanced-predictor
- Experiments: financial-ab-test-experiment
```

**Current Status**: ✅ **WORKING** - All Seldon functionality operational

## Migration Procedures

### A. Enabling Single Namespace Pattern (What We Did)

#### Step 1: Update Seldon Controller Configuration
```yaml
# Set controller to cluster-wide mode
controller:
  clusterwide: true
```

#### Step 2: Deploy Resources to seldon-system
```bash
# Move ServerConfig to seldon-system namespace
kubectl get serverconfig mlserver-config -n financial-mlops-pytorch -o yaml | \
  sed 's/namespace: financial-mlops-pytorch/namespace: seldon-system/' | \
  kubectl apply -f -

# Move Server to seldon-system namespace  
kubectl get server mlserver -n financial-mlops-pytorch -o yaml | \
  sed 's/namespace: financial-mlops-pytorch/namespace: seldon-system/' | \
  kubectl apply -f -

# Move other resources similarly...
```

#### Step 3: Clean Up Application Namespace
```bash
# Remove old resources from application namespace
kubectl delete serverconfig,server,model,experiment --all -n financial-mlops-pytorch
```

### B. Rolling Back to Scoped Operator Pattern

#### Step 1: Revert Seldon Controller to Namespace-Scoped
```yaml
# In infrastructure/cluster/roles/platform/seldon/tasks/main.yml
controller:
  clusterwide: false
  watchNamespaces: ["financial-mlops-pytorch", "financial-inference"]
```

#### Step 2: Redeploy Seldon Configuration
```bash
ansible-playbook -i inventory/production/hosts infrastructure/cluster/site.yml --tags seldon
```

#### Step 3: Move Resources Back to Application Namespaces
```bash
# Move ServerConfig back to application namespace
kubectl get serverconfig mlserver-config -n seldon-system -o yaml | \
  sed 's/namespace: seldon-system/namespace: financial-mlops-pytorch/' | \
  kubectl apply -f -

# Move Server back to application namespace
kubectl get server mlserver -n seldon-system -o yaml | \
  sed 's/namespace: seldon-system/namespace: financial-mlops-pytorch/' | \
  kubectl apply -f -

# Move other resources...
```

#### Step 4: Verify Failure (Expected with v2.9.1)
```bash
# These will fail due to the namespace lookup bug
kubectl get servers -n financial-mlops-pytorch
# Expected: Empty images, pod creation failures
```

### C. Implementing Custom Controller Fix

#### Step 1: Complete Steps B.1-B.4 (Revert to Scoped Pattern)

#### Step 2: Apply Custom Controller Image
```bash
# Patch controller to use fixed image
kubectl patch deployment seldon-v2-controller-manager -n seldon-system \
  --patch '{"spec":{"template":{"spec":{"containers":[{"name":"manager","image":"harbor.test/library/seldon-controller:fix-namespace-lookup"}]}}}}'
```

#### Step 3: Monitor Rollout
```bash
kubectl rollout status deployment/seldon-v2-controller-manager -n seldon-system
```

#### Step 4: Verify Fix
```bash
# Check controller image
kubectl describe pod -n seldon-system -l app.kubernetes.io/name=seldon-v2-controller-manager | grep "Image:"
# Should show: harbor.test/library/seldon-controller:fix-namespace-lookup

# Test ServerConfig lookup in application namespace
kubectl describe statefulset mlserver -n financial-mlops-pytorch
# Should show: Correct container images from ServerConfig
```

#### Step 5: Update Ansible for Persistence
```yaml
# In infrastructure/cluster/roles/platform/seldon/defaults/main.yml
seldon_controller_image: "harbor.test/library/seldon-controller"
seldon_controller_tag: "fix-namespace-lookup"

# In infrastructure/cluster/roles/platform/seldon/tasks/main.yml
controllerManager:
  image:
    repository: "{{ seldon_controller_image }}"
    tag: "{{ seldon_controller_tag }}"
```

## Configuration Comparison

### Current Configuration (Single Namespace)
```yaml
# Ansible configuration
controller:
  clusterwide: true

# Resource deployment
namespace: seldon-system  # All resources here
```

### Target Configuration (Scoped Operator with Fix)
```yaml
# Ansible configuration  
controller:
  clusterwide: false
  watchNamespaces: ["financial-mlops-pytorch", "financial-inference"]
controllerManager:
  image:
    repository: "harbor.test/library/seldon-controller"
    tag: "fix-namespace-lookup"

# Resource deployment
namespace: financial-mlops-pytorch  # Application resources here
```

## Testing Strategy

### Test Case 1: Single Namespace Pattern (Current)
```bash
# Verify current working state
kubectl get serverconfig,server,model -n seldon-system
kubectl get pods -n seldon-system -l seldon-server-name=mlserver
# Expected: All resources present and functional
```

### Test Case 2: Scoped Operator Pattern (After Fix)
```bash
# Verify multi-namespace functionality
kubectl get serverconfig,server,model -n financial-mlops-pytorch
kubectl describe statefulset mlserver -n financial-mlops-pytorch | grep "Image:"
kubectl get pods -n financial-mlops-pytorch -l seldon-server-name=mlserver
# Expected: Resources in app namespace, correct images, working pods
```

## Risk Assessment

### Single Namespace Pattern Risks
- **Low Risk**: Proven working configuration
- **Operational Impact**: Teams must coordinate deployments
- **Security Impact**: Reduced namespace isolation

### Scoped Operator Pattern Risks
- **Medium Risk**: Depends on custom controller image
- **Operational Impact**: Requires controller image management
- **Security Impact**: Improved namespace isolation
- **Technical Risk**: Custom image maintenance overhead

## Recommendations

### Immediate (Next 24 hours)
1. **Stay with Single Namespace Pattern** until custom controller is fully tested
2. **Test custom controller in development environment** first
3. **Create rollback procedures** for quick recovery

### Short Term (1-2 weeks)
1. **Implement custom controller** if testing successful
2. **Migrate to Scoped Operator Pattern** for proper multi-tenancy
3. **Update platform documentation** with new patterns

### Long Term (1-2 months)
1. **Monitor Seldon Core v2.9.2** for upstream fix
2. **Evaluate migration back to upstream controller** when bug is fixed
3. **Standardize on preferred pattern** across all environments

## Status Summary

- **Current State**: Single Namespace Pattern (Working)
- **Target State**: Scoped Operator Pattern with Custom Controller Fix
- **Migration Path**: Documented and ready for execution
- **Risk Level**: Medium (requires custom controller maintenance)
- **Timeline**: Ready to execute when approved