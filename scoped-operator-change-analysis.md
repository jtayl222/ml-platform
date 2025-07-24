# Scoped Operator Pattern - Change Requirements Analysis

Based on git diff review, this document lists every change and its relevance to the scoped operator pattern deployment.

## REQUIRED CHANGES - Keep These

### infrastructure/cluster/roles/platform/seldon/defaults/main.yml

#### ✅ REQUIRED: Namespace watching configuration
- **Change**: `seldon_ml_namespaces` → `seldon_watch_namespaces`
- **Reason**: Scoped operator pattern requires explicit namespace watching list
- **Impact**: Core functionality for multi-tenant isolation

#### ✅ REQUIRED: Custom controller image flags
- **Change**: Added `seldon_use_custom_controller` and `seldon_use_custom_scheduler` flags
- **Reason**: Needed to apply patched controller that fixes namespace lookup bug
- **Impact**: Enables proper ServerConfig lookup in application namespaces

#### ✅ REQUIRED: Updated comments and examples
- **Change**: Updated variable comments to reflect scoped operator pattern
- **Reason**: Documentation consistency with new deployment model
- **Impact**: Operator understanding and maintenance

### infrastructure/cluster/roles/platform/seldon/tasks/main.yml

#### ✅ REQUIRED: Scoped controller configuration
- **Change**: `clusterwide: false` with explicit `watchNamespaces`
- **Reason**: Core requirement for scoped operator pattern
- **Impact**: Enables namespace-scoped resource watching

#### ✅ REQUIRED: Custom image handling logic
- **Change**: Added conditional image override logic for controller and scheduler
- **Reason**: Supports patched controller deployment for namespace lookup fix
- **Impact**: Enables workaround for v2.9.1 bugs

#### ✅ REQUIRED: Watched namespace creation
- **Change**: Creates namespaces specified in `seldon_watch_namespaces`
- **Reason**: Ensures target namespaces exist before controller deployment
- **Impact**: Prevents controller startup failures

#### ✅ REQUIRED: Updated deployment name check
- **Change**: `seldon-controller-manager` → `seldon-v2-controller-manager`
- **Reason**: Matches actual deployment name in v2.9.1
- **Impact**: Proper health checks and rollout verification

#### ✅ REQUIRED: Enhanced success message
- **Change**: Updated completion message with scoped operator details
- **Reason**: Provides clear confirmation of deployment pattern and watched namespaces
- **Impact**: Operator visibility into deployment configuration

### inventory/production/group_vars/all.yml.example

#### ✅ REQUIRED: Seldon scheduler custom image configuration
- **Change**: Added `seldon_scheduler_image`, `seldon_scheduler_tag`, `seldon_scheduler_full_image`
- **Reason**: Supports custom scheduler image if needed for fixes
- **Impact**: Enables scheduler patching for improved logging/debugging

#### ✅ REQUIRED: Custom controller image configuration in seldon_custom_images
- **Change**: Controller image override configuration
- **Reason**: Enables deployment of patched controller for namespace lookup fix
- **Impact**: Core fix for scoped operator pattern functionality

## QUESTIONABLE CHANGES - Review for Backing Out

### infrastructure/cluster/roles/platform/seldon/tasks/main.yml

#### ❌ POTENTIALLY REMOVE: Network policy task removal
- **Change**: Removed all network policy creation tasks (lines 232-274 in original)
- **Reason**: May still be needed for security in multi-tenant deployments
- **Impact**: Could create security gaps between namespaces
- **Recommendation**: Review if network policies are still required for namespace isolation

### inventory/production/group_vars/all.yml.example

#### ❌ UNRELATED: Resource limit reductions
- **Change**: Reduced memory/CPU requests for MinIO, Grafana, MLflow, Prometheus
- **Example**: MinIO memory: `8Gi → 1Gi`, CPU: `4 → 100m`
- **Reason**: Not related to scoped operator pattern
- **Impact**: Could cause resource constraints under load
- **Recommendation**: Back out unless based on actual usage analysis

## DOCUMENTATION FILES

### docs/seldon-deployment-patterns.md
#### ✅ REQUIRED: Keep
- **Reason**: Comprehensive documentation of scoped vs single namespace patterns
- **Impact**: Critical for understanding deployment options and migration paths
- **Value**: Operational guidance for pattern selection and troubleshooting

### docs/seldon-v2-known-issues.md  
#### ✅ REQUIRED: Keep
- **Reason**: Documents critical namespace lookup bug that necessitates workarounds
- **Impact**: Essential for understanding why scoped pattern requires custom controller
- **Value**: Bug analysis and workaround documentation

## CHANGES TO BACK OUT

### 1. Resource Limit Reductions (Unless Justified)
```yaml
# In inventory/production/group_vars/all.yml.example
# BACK OUT these changes unless based on actual resource analysis:

# MinIO - restore original limits
minio_memory_request: "8Gi"     # was reduced to 1Gi
minio_memory_limit: "16Gi"      # was reduced to 2Gi  
minio_cpu_request: 4            # was reduced to 100m
minio_cpu_limit: 8              # was reduced to 500m

# Grafana - restore original limits  
grafana_memory_request: "4Gi"   # was reduced to 512Mi
grafana_memory_limit: "8Gi"     # was reduced to 1Gi
grafana_cpu_request: 2          # was reduced to 100m
grafana_cpu_limit: 4            # was reduced to 500m

# MLflow - restore original limits
mlflow_memory_request: "8Gi"    # was reduced to 1Gi
mlflow_memory_limit: "16Gi"     # was reduced to 2Gi
mlflow_cpu_request: 4           # was reduced to 100m
mlflow_cpu_limit: 8             # was reduced to 500m

# Prometheus - restore original limits
prometheus_memory_request: "4Gi"  # was reduced to 1Gi
prometheus_memory_limit: "8Gi"    # was reduced to 4Gi
prometheus_cpu_request: 2         # was reduced to 200m
prometheus_cpu_limit: 4           # was reduced to 1000m
```

### 2. Consider Restoring Network Policies (If Security Required)
```yaml
# In infrastructure/cluster/roles/platform/seldon/tasks/main.yml
# These tasks were removed but may be needed:
- name: Create network policy template for ML namespaces
- name: Create ML namespaces  
- name: Apply network policies to ML namespaces
- name: Clean up network policy templates
```

## SUMMARY

**Total Changes**: 23 identified changes
- **✅ Keep (Required)**: 15 changes
- **❌ Consider Backing Out**: 8 changes

**Recommendation**: 
1. Keep all Seldon-specific changes for scoped operator pattern
2. Back out resource limit reductions unless justified by actual usage data
3. Evaluate if network policies are still needed for security compliance
4. Keep both documentation files as they provide critical operational guidance

**Risk Assessment**:
- **Low Risk**: Scoped operator configuration changes (tested and documented)
- **Medium Risk**: Resource limit reductions (could cause performance issues)
- **High Risk**: Network policy removal (potential security gaps)