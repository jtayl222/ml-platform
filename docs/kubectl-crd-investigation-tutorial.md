# Investigating Kubernetes CRDs with kubectl and yq: A Practical Guide

*How to reverse-engineer the correct YAML structure for complex Kubernetes operators*

---

## The Problem

You've deployed Seldon Core V2 with what you thought was the correct configuration for cluster-wide model watching:

```yaml
env:
  - name: CLUSTERWIDE
    value: "true"
args:
  - --clusterwide=true
```

But when you check the deployment, you see:

```bash
$ kubectl describe deployment seldon-v2-controller-manager -n seldon-system | grep CLUSTERWIDE
CLUSTERWIDE: false
```

The configuration didn't take effect! How do you find the correct YAML structure?

## The Investigation Process

### Step 1: Find the CRDs

First, discover what Custom Resource Definitions (CRDs) Seldon installed:

```bash
# List all CRDs related to Seldon
kubectl get crd | grep seldon

# Example output:
# seldonconfigs.mlops.seldon.io
# seldonmodels.mlops.seldon.io
# seldonruntimes.mlops.seldon.io
```

### Step 2: Examine the Configuration CRD

The `seldonconfigs.mlops.seldon.io` CRD likely controls operator behavior:

```bash
# Get the CRD definition
kubectl get crd seldonconfigs.mlops.seldon.io -o yaml > seldonconfig-crd.yaml

# Use yq to explore the schema structure
yq '.spec.versions[0].schema.openAPIV3Schema.properties' seldonconfig-crd.yaml
```

### Step 3: Find Current Configuration

Look for existing SeldonConfig resources:

```bash
# Check for existing configurations
kubectl get seldonconfigs -A

# If one exists, examine it
kubectl get seldonconfig seldon-config -n seldon-system -o yaml
```

### Step 4: Use yq to Navigate the Schema

Here's how to systematically explore the CRD schema:

```bash
# See top-level properties
yq '.spec.versions[0].schema.openAPIV3Schema.properties | keys' seldonconfig-crd.yaml

# Dive into spec properties
yq '.spec.versions[0].schema.openAPIV3Schema.properties.spec.properties | keys' seldonconfig-crd.yaml

# Look for controller-related settings
yq '.spec.versions[0].schema.openAPIV3Schema.properties.spec.properties.controller' seldonconfig-crd.yaml
```

### Step 5: Practical Example - Finding the Clusterwide Setting

Let's walk through finding the correct structure for the clusterwide setting:

```bash
# Export the CRD for easier manipulation
kubectl get crd seldonconfigs.mlops.seldon.io -o yaml > seldonconfig-crd.yaml

# Find all properties that might relate to "cluster" or "wide"
yq '.. | select(type == "object") | to_entries[] | select(.key | test("cluster|wide|scope"; "i"))' seldonconfig-crd.yaml

# Look for controller configuration
yq '.spec.versions[0].schema.openAPIV3Schema.properties.spec.properties.controller.properties' seldonconfig-crd.yaml

# Check if there's a clusterwide property
yq '.spec.versions[0].schema.openAPIV3Schema.properties.spec.properties.controller.properties.clusterwide' seldonconfig-crd.yaml
```

### Step 6: Create the Correct Configuration

Based on the CRD investigation, create the proper SeldonConfig:

```yaml
# seldon-clusterwide-config.yaml
apiVersion: mlops.seldon.io/v1alpha1
kind: SeldonConfig
metadata:
  name: seldon-config
  namespace: seldon-system
spec:
  controller:
    clusterwide: true
    # Other controller settings...
```

## Advanced yq Techniques for CRD Investigation

### Finding Enum Values

```bash
# Find allowed values for specific properties
yq '.spec.versions[0].schema.openAPIV3Schema.properties.spec.properties.controller.properties.logLevel.enum' seldonconfig-crd.yaml
```

### Exploring Nested Structures

```bash
# Get all paths to leaf properties
yq -r '
  def paths: path(leaf_paths) as $p | $p | join(".");
  .spec.versions[0].schema.openAPIV3Schema | paths
' seldonconfig-crd.yaml | grep -E "(cluster|wide|scope)"
```

### Finding Required Fields

```bash
# Check which fields are required at each level
yq '.spec.versions[0].schema.openAPIV3Schema.properties.spec.required' seldonconfig-crd.yaml
```

### Getting Property Descriptions

```bash
# Find descriptions for specific properties
yq '.spec.versions[0].schema.openAPIV3Schema.properties.spec.properties.controller.properties.clusterwide.description' seldonconfig-crd.yaml
```

## Helm-Specific Investigation

When using Helm, you also need to understand how Helm values map to the final YAML:

### Step 1: Get Helm Values Schema

```bash
# Get the current values
helm get values seldon-core-v2-setup -n seldon-system

# Get default values from the chart
helm show values seldon/seldon-core-v2-setup > seldon-values.yaml
```

### Step 2: Find the Correct Helm Path

```bash
# Search for clusterwide in Helm values
yq '.. | select(type == "object") | to_entries[] | select(.key | test("cluster|wide"; "i"))' seldon-values.yaml

# Look for controller configuration in Helm values
yq '.controller' seldon-values.yaml
```

### Step 3: Compare Rendered vs Expected

```bash
# Render the template locally to see what would be generated
helm template seldon-core-v2-setup seldon/seldon-core-v2-setup \
  --set controller.clusterwide=true \
  --namespace seldon-system > rendered-seldon.yaml

# Extract the SeldonConfig from rendered output
yq 'select(.kind == "SeldonConfig")' rendered-seldon.yaml
```

## Real-World Example: The Seldon Chart Confusion

This investigation revealed a **common problem** with multi-chart Kubernetes operators: **chart separation can create configuration confusion**.

### **The Root Cause Discovery:**
After extensive debugging, we discovered the real issue:

```bash
# ❌ WRONG: We were configuring the runtime chart
helm upgrade seldon-core-v2-runtime seldon/seldon-core-v2-runtime \
  --set controller.clusterwide=true

# ✅ CORRECT: Controller is installed by the setup chart  
helm upgrade seldon-core-v2-setup seldon/seldon-core-v2-setup \
  --set controller.clusterwide=true
```

### **Why This Happened:**
1. **Chart Separation:** Seldon splits installation across multiple charts:
   - `seldon-core-v2-setup` → Installs the controller
   - `seldon-core-v2-runtime` → Installs runtime components
   - `seldon-core-v2-servers` → Installs model servers

2. **Documentation Ambiguity:** Official docs didn't clearly specify which chart controls which settings

3. **Silent Failures:** The runtime chart accepts `controller.clusterwide` values but ignores them (no controller to configure)

### **What We Actually Tested:**
```bash
# All failed because we were configuring the wrong chart:
helm upgrade seldon-core-v2-runtime ... --set controller.clusterwide=true           # ❌ Wrong chart
helm upgrade seldon-core-v2-runtime ... --set controllerManager.clusterwide=true   # ❌ Wrong chart  
helm upgrade seldon-core-v2-runtime ... --set controllerManager.env[0].name=...    # ❌ Wrong chart
```

### **The Correct Solution:**
```bash
# Configure the setup chart that actually installs the controller
helm upgrade seldon-core-v2-setup seldon/seldon-core-v2-setup \
  --namespace seldon-system \
  --set controller.clusterwide=true
```

### **Key Insights:**
1. **Multi-chart operators require chart mapping** - know which chart controls what
2. **Silent value acceptance is dangerous** - charts should reject invalid values
3. **Documentation should specify chart responsibilities** clearly
4. **Systematic investigation pays off** - eventually reveals the real issue

## Verification

After applying the correct configuration:

```bash
# Check the SeldonConfig
kubectl get seldonconfig seldon-config -n seldon-system -o yaml

# Verify the deployment reflects the change
kubectl describe deployment seldon-v2-controller-manager -n seldon-system | grep CLUSTERWIDE

# Should now show: CLUSTERWIDE: true
```

## Common Patterns and Tips

### 1. CRD Schema Exploration Commands

```bash
# Quick overview of all properties
yq '.spec.versions[0].schema.openAPIV3Schema.properties | keys' <crd-file>

# Find all string properties (often configuration flags)
yq '.spec.versions[0].schema.openAPIV3Schema | .. | select(.type? == "string") | parent | key' <crd-file>

# Find all boolean properties (often feature flags)
yq '.spec.versions[0].schema.openAPIV3Schema | .. | select(.type? == "boolean") | parent | key' <crd-file>
```

### 2. Helm Value Investigation

```bash
# Find all possible configuration paths
helm show values <chart> | yq -r 'paths(scalars) as $p | $p | join(".")'

# Search for specific configuration patterns
helm show values <chart> | yq '.. | select(type == "object") | to_entries[] | select(.value | type == "boolean")'
```

### 3. Operator Configuration Patterns

Most Kubernetes operators follow these patterns:

- **Global settings:** Usually in a config CRD (e.g., `SeldonConfig`, `PrometheusConfig`)
- **Per-resource settings:** In the main CRDs (e.g., `SeldonModel`, `ServiceMonitor`)
- **Deployment settings:** In Helm values that configure the operator deployment

## Troubleshooting Common Issues

### Issue 1: Configuration Not Applied

```bash
# Check if the config CRD exists and is applied
kubectl get <config-crd-name> -A

# Check operator logs for configuration errors
kubectl logs deployment/<operator-name> -n <operator-namespace>
```

### Issue 2: Helm Values Not Taking Effect

```bash
# Verify Helm actually updated the resources
helm history <release-name> -n <namespace>

# Compare what Helm thinks vs what's actually deployed
helm get manifest <release-name> -n <namespace> > expected.yaml
kubectl get <resource> <name> -n <namespace> -o yaml > actual.yaml
diff expected.yaml actual.yaml
```

### Issue 3: Schema Validation Errors

```bash
# Validate your YAML against the CRD schema
kubectl apply --dry-run=server -f your-config.yaml

# Use yq to validate structure before applying
yq eval 'select(.kind == "YourCRD") | .spec' your-config.yaml
```

## The Bigger Problem: Kubernetes Ecosystem Quality

This investigation reveals **systemic issues** in the Kubernetes ecosystem:

### **Why This Matters for MLOps Engineers**

**Time Waste:**
- Hours spent debugging basic configuration
- Multiple failed attempts with "official" solutions
- Manual workarounds that break GitOps workflows

**Operational Risk:**
- Configuration drift from manual editing
- Unreliable infrastructure automation
- Difficult troubleshooting in production

**Team Friction:**
- Infrastructure team becomes bottleneck
- Application teams lose confidence in platform
- Poor developer experience slows adoption

### **What the Ecosystem Needs**

1. **Better Quality Control**
   - Integration tests for Helm chart value mappings
   - Documentation validation against actual implementations
   - Clear compatibility matrices

2. **Improved Developer Experience**
   - Standardized configuration patterns
   - Better error messages when values are ignored
   - Discovery tools for valid configuration paths

3. **Transparency**
   - Clear indication when features are unsupported
   - Explicit compatibility warnings
   - Community-driven validation tools

## Conclusion

Understanding how to investigate CRDs with `kubectl` and `yq` is **unfortunately necessary** for working with complex Kubernetes operators, but it **shouldn't be**. This systematic approach helps you:

1. **Survive broken documentation** and faulty Helm charts
2. **Find working solutions** when official approaches fail
3. **Provide evidence** when filing bugs with upstream projects
4. **Protect your time** from endless trial-and-error

**The real takeaway:** The Kubernetes ecosystem needs to prioritize **usability and reliability** over feature complexity. Until then, MLOps engineers need defensive investigation techniques to work around these systemic problems.

This investigative process is crucial for MLOps engineers working with sophisticated platforms like Seldon Core, Kubeflow, or Istio, where configuration can be complex and **documentation is often wrong**.

---

*This tutorial demonstrates the unfortunate reality of Kubernetes troubleshooting skills required for production MLOps environments - and why the ecosystem needs to improve.*