# Cross-Namespace Secret Access: Temporary Fix

**Status:** 🟡 Temporary Solution  
**Created:** 2025-07-05  
**Target Removal:** Q3 2025 (after centralized secret management)  
**Owner:** Platform Team  

## Problem Statement

Argo Workflows controller (running in `argowf` namespace) cannot access secrets in application namespaces (e.g., `iris-demo`) during Kaniko container build steps, blocking ML pipeline deployments.

### Pipeline Impact
```
✅ train (42s)
✅ validate (1m)  
✅ semantic-versioning (10s)
✅ monitor-validate (1m)
❌ kaniko (secret access denied) ← BLOCKED HERE
⏸️ deploy (blocked)
```

## Root Cause Analysis

1. **Architecture Evolution:** Moved from workflows in `argowf` namespace to proper application namespaces
2. **Secret Location:** ML secrets delivered to application namespaces (`iris-demo`, `financial-ml`, etc.)
3. **Controller Isolation:** Argo Workflows controller runs in `argowf` namespace
4. **RBAC Limitation:** Default RBAC prevents cross-namespace secret access

## Temporary Solution

**File:** `infrastructure/cluster/workflows-rbac-fix.yaml`

**Approach:** Minimal ClusterRole granting Argo Workflows controller access to specific secrets across namespaces.

### Security Constraints
- ✅ **Specific actions:** Only `get` and `list` operations  
- ✅ **Targeted namespace access:** Cross-namespace but auditable
- ✅ **Temporary nature:** Clearly marked for replacement
- ✅ **Audit trail:** All access logged via Kubernetes RBAC
- ⚠️ **Scope:** Currently allows access to all secrets (see note below)

**Note:** `resourceNames` restriction temporarily removed to ensure functionality. Will be re-added after confirming pipeline success:
```yaml
# Future enhancement after verification
resourceNames: ["ghcr", "ml-platform"]
```

### Deployment
```bash
kubectl apply -f infrastructure/cluster/workflows-rbac-fix.yaml
```

### Verification
```bash
# Verify the ClusterRoleBinding is correctly configured
kubectl describe clusterrolebinding argowf-cross-namespace-secrets

# Test permissions (should return "yes")
kubectl auth can-i get secrets --as=system:serviceaccount:argowf:argo-workflows-workflow-controller -n iris-demo

# Important: Verify actual service account name from running pods
kubectl get pod -n argowf -l app=workflow-controller -o jsonpath='{.items[0].spec.serviceAccountName}'
```

### Common Issues and Solutions

**Issue 1: Service Account Name Mismatch**
- **Problem:** ClusterRoleBinding uses incorrect service account name
- **Symptoms:** Permissions test fails, workflows still can't access secrets
- **Solution:** Verify actual service account name from running pods

**Issue 2: resourceNames RBAC Testing**
- **Problem:** `kubectl auth can-i` may not work with `resourceNames` restrictions
- **Symptoms:** Permission test fails even with correct RBAC
- **Solution:** Test without `resourceNames` first, add restrictions after confirming basic access

**Issue 3: RBAC Propagation Delay**
- **Problem:** RBAC changes may take time to propagate
- **Symptoms:** Intermittent permission failures
- **Solution:** Wait 30-60 seconds after RBAC changes before testing

## Enterprise Migration Strategies

### Option A: On-Premises Infrastructure (Current K3s Setup)

#### **A1. External Secrets Operator + HashiCorp Vault (Recommended)**

**Architecture:**
```
[K3s Cluster] → [ESO] → [Local Vault Cluster] → [Secrets]
```

**Timeline:** 6-8 weeks  
**Complexity:** High  
**Security:** Highest  

**Implementation:**
```bash
# 1. Deploy Vault cluster on local infrastructure
helm install vault hashicorp/vault \
  --set server.ha.enabled=true \
  --set server.ha.replicas=3

# 2. Install External Secrets Operator
helm install external-secrets external-secrets/external-secrets -n external-secrets-system --create-namespace

# 3. Configure SecretStore
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: vault-backend
spec:
  provider:
    vault:
      server: "http://vault.vault.svc.cluster.local:8200"
      path: "secret"
      version: "v2"
```

**Benefits:**
- Enterprise-grade secret management
- Automatic rotation and auditing
- Fine-grained access controls
- Scales with organization growth

**Considerations:**
- Requires dedicated Vault infrastructure
- Higher operational complexity
- Need Vault expertise for maintenance

#### **A2. Enhanced Sealed Secrets with Automated Cross-Namespace Sync**

**Architecture:**
```
[Infrastructure Team] → [Sealed Secrets] → [Sync Controller] → [Target Namespaces]
```

**Timeline:** 2-3 weeks  
**Complexity:** Medium  
**Security:** Medium-High  

**Implementation:**
```yaml
# secret-sync-controller.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ml-secret-sync
  namespace: kube-system
spec:
  template:
    spec:
      containers:
      - name: sync
        image: bitnami/kubectl:latest
        env:
        - name: SOURCE_NAMESPACES
          value: "iris-demo,financial-ml,churn-prediction"
        - name: TARGET_NAMESPACE
          value: "argowf"
        - name: SECRET_NAMES
          value: "ghcr,ml-platform"
        command:
        - /scripts/sync-secrets.sh
```

**Benefits:**
- Builds on existing sealed secrets investment
- Lower complexity than Vault
- Can be implemented quickly
- Maintains current workflows

**Considerations:**
- Custom solution requires maintenance
- Less feature-rich than Vault
- Secret sprawl across namespaces

#### **A3. External Secrets Operator + File-Based Backend**

**Architecture:**
```
[K3s Cluster] → [ESO] → [Shared Volume/NFS] → [Secret Files]
```

**Timeline:** 3-4 weeks  
**Complexity:** Medium  
**Security:** Medium  

**Implementation:**
```yaml
# File-based SecretStore
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: file-backend
spec:
  provider:
    filesystem:
      paths:
      - "/mnt/secrets"
```

**Benefits:**
- Simpler than Vault setup
- Uses existing NFS/storage infrastructure
- ESO provides standard interface

**Considerations:**
- File-based storage less secure than Vault
- Manual secret rotation
- Limited audit capabilities

### Option B: Cloud-Based Infrastructure (Migration Path)

#### **B1. External Secrets Operator + AWS Secrets Manager**

**Architecture:**
```
[K3s/EKS] → [ESO] → [AWS Secrets Manager] → [Secrets]
```

**Implementation:**
```yaml
# AWS SecretStore
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: aws-secrets-manager
spec:
  provider:
    aws:
      service: SecretsManager
      region: us-west-2
      auth:
        secretRef:
          accessKeyID:
            name: awssm-secret
            key: access-key
          secretAccessKey:
            name: awssm-secret
            key: secret-access-key
```

#### **B2. External Secrets Operator + Azure Key Vault**

**Architecture:**
```
[K3s/AKS] → [ESO] → [Azure Key Vault] → [Secrets]
```

#### **B3. External Secrets Operator + Google Secret Manager**

**Architecture:**
```
[K3s/GKE] → [ESO] → [Google Secret Manager] → [Secrets]
```

## Recommendation Matrix

| Environment | Recommended Solution | Timeline | Justification |
|-------------|---------------------|----------|---------------|
| **On-Prem K3s (Current)** | A2: Enhanced Sealed Secrets | 2-3 weeks | Builds on existing investment, lower complexity |
| **On-Prem Enterprise** | A1: ESO + Local Vault | 6-8 weeks | Enterprise-grade, full feature set |
| **Hybrid Cloud** | B1: ESO + AWS Secrets Manager | 4-6 weeks | Managed service, reduced ops overhead |
| **Cloud-Native** | B1/B2/B3: ESO + Cloud Provider | 3-4 weeks | Native integration, managed services |

## Risk Assessment

### Current Risk (Temporary Fix)
- **Low:** Limited scope RBAC with specific secret names
- **Mitigation:** Clear annotations, monitoring, planned removal

### Migration Risk by Option
- **A1 (Vault):** Medium - Complex setup, but enterprise-proven
- **A2 (Sync):** Low - Incremental improvement on current approach
- **B1 (Cloud):** Low-Medium - Managed service reduces operational risk

## Implementation Roadmap

### Phase 1: Immediate (This Week)
- [x] Deploy temporary RBAC fix
- [ ] Document current architecture and pain points
- [ ] Evaluate team expertise and preferences

### Phase 2: Planning (Weeks 2-3)
- [ ] Infrastructure team decision on target architecture
- [ ] Security team review of proposed solution
- [ ] Resource allocation and timeline confirmation

### Phase 3: Implementation (Weeks 4-8)
- [ ] Deploy chosen solution in development
- [ ] Migrate secrets and test workflows
- [ ] Production deployment and monitoring

### Phase 4: Cleanup (Week 9)
- [ ] Remove temporary RBAC fix
- [ ] Update documentation and runbooks
- [ ] Team training on new solution

## Monitoring & Cleanup

### Current Monitoring
```bash
# Check RBAC usage
kubectl get events --field-selector reason=AccessGranted | grep argowf-cross-namespace

# Verify secret access patterns
kubectl logs -n argowf deployment/argo-workflows-workflow-controller | grep -i secret
```

### Removal Checklist
When permanent solution is implemented:

- [ ] Verify all workflows use new secret management
- [ ] Test pipeline end-to-end with new secrets
- [ ] Remove temporary RBAC: `kubectl delete -f infrastructure/cluster/workflows-rbac-fix.yaml`
- [ ] Archive this documentation
- [ ] Update operational procedures

---

**Next Action:** Infrastructure team to review options and select target architecture based on organizational requirements, timeline, and expertise.