# Seldon Core v2 Known Issues and Workarounds

## Critical Bug: Cross-Namespace ServerConfig References (v2.9.1)

### Issue Description
Seldon Core v2.9.1 has a critical bug where Server resources cannot reference ServerConfig resources in different namespaces. The operator fails to parse the `namespace/name` format in `Server.spec.serverConfig`.

**Affected Versions**: v2.9.0, v2.9.1
**GitHub Issue**: Not yet reported upstream - platform team should file this issue
**Status**: Confirmed in production, workaround available

### Symptoms
```yaml
# This WILL NOT WORK in v2.9.1
apiVersion: mlops.seldon.io/v1alpha1
kind: Server
metadata:
  name: mlserver
  namespace: fraud-detection
spec:
  serverConfig: seldon-system/mlserver-config  # ❌ Fails with "not found"
```

Error message:
```
Server Status: NOT READY
Reason: ServerConfig.mlops.seldon.io "seldon-system/mlserver-config" not found
```

### Root Cause
The Seldon operator in v2.9.1 treats the entire string "seldon-system/mlserver-config" as the resource name instead of parsing it as `namespace/name`.

## Workarounds

### Option 1: Copy ServerConfig to Application Namespace (Recommended)

**Responsibility**: Application Team

Application teams must copy the ServerConfig from `seldon-system` to their namespace:

```bash
# Copy ServerConfig to your namespace
kubectl get serverconfig mlserver-config -n seldon-system -o yaml | \
  sed 's/namespace: seldon-system/namespace: fraud-detection/' | \
  kubectl apply -f -
```

Then update your Server resource to reference the local copy:
```yaml
apiVersion: mlops.seldon.io/v1alpha1
kind: Server
metadata:
  name: mlserver
  namespace: fraud-detection
spec:
  serverConfig: mlserver-config  # ✅ No namespace prefix
```

### Option 2: Use Kustomize for Automatic ServerConfig Duplication

Create a kustomization that automatically copies ServerConfigs:

```yaml
# k8s/base/serverconfig-copy.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - server.yaml
  - model.yaml

# Add a pre-deployment job
configMapGenerator:
  - name: copy-serverconfig-script
    files:
      - copy-serverconfig.sh

# copy-serverconfig.sh
#!/bin/bash
for config in mlserver mlserver-config triton; do
  kubectl get serverconfig $config -n seldon-system -o yaml 2>/dev/null | \
    sed "s/namespace: seldon-system/namespace: ${NAMESPACE}/" | \
    kubectl apply -f -
done
```

### Option 3: Use Helm Post-Install Hook

For Helm deployments, use a post-install hook:

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: copy-serverconfigs
  annotations:
    "helm.sh/hook": post-install,post-upgrade
    "helm.sh/hook-weight": "-5"
spec:
  template:
    spec:
      serviceAccountName: serverconfig-copier
      containers:
      - name: copy
        image: bitnami/kubectl:latest
        command:
        - /bin/sh
        - -c
        - |
          for config in mlserver mlserver-config triton; do
            kubectl get serverconfig $config -n seldon-system -o yaml | \
              sed 's/namespace: seldon-system/namespace: {{ .Release.Namespace }}/' | \
              kubectl apply -f -
          done
      restartPolicy: Never
```

## Platform Team Responsibilities

### 1. Report Issue Upstream
Platform team should file this issue with Seldon Core team:
- Repository: https://github.com/SeldonIO/seldon-core/issues
- Include minimal reproducible example
- Reference this documentation for workarounds
- Track fix in future releases (expected v2.10.0+)

### 2. Documentation
Platform team should document this known issue in:
- Platform onboarding documentation
- ML deployment guidelines
- Troubleshooting guides

### 3. Provide Helper Scripts
Create and maintain helper scripts for application teams:

```bash
#!/bin/bash
# scripts/copy-seldon-serverconfigs.sh
NAMESPACE=${1:-$(kubectl config view --minify -o jsonpath='{..namespace}')}

echo "Copying ServerConfigs from seldon-system to $NAMESPACE..."

for config in mlserver mlserver-config triton; do
  if kubectl get serverconfig $config -n seldon-system &>/dev/null; then
    echo "  Copying $config..."
    kubectl get serverconfig $config -n seldon-system -o yaml | \
      sed "s/namespace: seldon-system/namespace: $NAMESPACE/" | \
      kubectl apply -f -
  fi
done

echo "ServerConfigs copied successfully!"
```

### 4. RBAC Setup
Ensure application namespaces have permission to read ServerConfigs:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: seldon-serverconfig-reader
rules:
- apiGroups: ["mlops.seldon.io"]
  resources: ["serverconfigs"]
  verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: seldon-serverconfig-reader
  namespace: {{ app_namespace }}
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: seldon-serverconfig-reader
subjects:
- kind: ServiceAccount
  name: default
  namespace: {{ app_namespace }}
```

## Application Team Responsibilities

### 1. Pre-Deployment Setup
Before deploying any Server resources:
```bash
# Copy required ServerConfigs to your namespace
./scripts/copy-seldon-serverconfigs.sh your-namespace
```

### 2. Server Configuration
Always reference ServerConfigs without namespace prefix:
```yaml
spec:
  serverConfig: mlserver-config  # ✅ Correct
  # NOT: serverConfig: seldon-system/mlserver-config  # ❌ Won't work
```

### 3. CI/CD Integration
Add ServerConfig copying to your deployment pipeline:
```yaml
# .gitlab-ci.yml or similar
deploy:
  script:
    - kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
    - ./scripts/copy-seldon-serverconfigs.sh $NAMESPACE
    - kubectl apply -k k8s/overlays/$ENVIRONMENT
```

## Verification Steps

1. **Check ServerConfigs are copied**:
   ```bash
   kubectl get serverconfig -n your-namespace
   ```

2. **Verify Server status**:
   ```bash
   kubectl get server -n your-namespace -o jsonpath='{.items[*].status.conditions[?(@.type=="Ready")]}' | jq
   ```

3. **Check pod creation**:
   ```bash
   kubectl get pods -n your-namespace -l app=mlserver
   ```

## Long-term Solution

This bug is expected to be fixed in Seldon Core v2.10.0 or later. Once fixed:
1. Platform team will upgrade Seldon Core
2. Application teams can use cross-namespace references
3. ServerConfig duplication will no longer be necessary

## Related Issues

- **PR #6617**: Service creation for disabled components (different issue)
- **Namespace lookup**: Core issue with ServerConfig resolution
- **Pattern 3 architecture**: Affects Standard Scoped Operator deployments

## Support

For assistance with this workaround:
- Platform Team: Contact via #ml-platform Slack channel
- Documentation: See platform wiki for deployment guides
- Scripts: Available in `platform-tools` repository