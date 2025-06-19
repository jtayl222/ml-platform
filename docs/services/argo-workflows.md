# 🔄 Argo Workflows Configuration & Usage

Complete guide to using Argo Workflows for ML pipeline orchestration and workflow automation.

## 🚀 **Quick Access**
- **URL**: [http://192.168.1.85:32746](http://192.168.1.85:32746)
- **Authentication**: Server mode (no login required)
- **CLI**: `argo` command-line interface
- **Kubernetes Integration**: Native CRDs and RBAC

## 🏗️ **Architecture Overview**

```
Argo Workflows Components
├── Workflow Controller (manages workflow execution)
├── Argo Server (Web UI & API)
├── Workflow Templates (reusable components)
├── Cluster Workflow Templates (cluster-wide templates)
└── Cron Workflows (scheduled executions)
```

## 🔧 **Configuration**

### **Current Deployment Settings**
```yaml
# Workflow Controller Configuration
workflowNamespaces: [argowf]
authModes: [server]
serviceType: NodePort
serviceNodePort: 32746
secure: false

# Node Distribution (Enhanced)
workflowDefaults:
  spec:
    affinity:
      nodeAffinity:
        preferredDuringSchedulingIgnoredDuringExecution:
        - weight: 100
          preference:
            matchExpressions:
            - key: node-role.kubernetes.io/worker
              operator: Exists
```

### **Supported Executors**
- **Docker**: Container execution (default)
- **Kubelet**: Direct kubelet execution
- **K8s API**: Kubernetes API-based execution
- **PNS**: Process Namespace Sharing

## 🧪 **Usage Examples**

### **Basic Workflow Submission**
```bash
# Submit a workflow
argo submit manifests/workflows/iris-workflow.yaml -n argowf

# Watch workflow progress
argo watch iris-demo -n argowf

# List all workflows
argo list -n argowf

# Get workflow details
argo get iris-demo -n argowf

# Get workflow logs
argo logs iris-demo -n argowf
```

### **Simple Workflow YAML**
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: hello-world-
spec:
  entrypoint: whalesay
  templates:
  - name: whalesay
    container:
      image: docker/whalesay
      command: [cowsay]
      args: ["Hello MLOps Platform!"]
```

### **ML Training Pipeline Example**
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: ml-pipeline-
spec:
  entrypoint: ml-training-pipeline
  
  # Workflow-level volumes
  volumes:
  - name: data-volume
    persistentVolumeClaim:
      claimName: ml-data-pvc
      
  templates:
  # Main pipeline orchestration
  - name: ml-training-pipeline
    dag:
      tasks:
      - name: data-preprocessing
        template: preprocess-data
      - name: model-training
        template: train-model
        depends: data-preprocessing
      - name: model-evaluation
        template: evaluate-model
        depends: model-training
      - name: model-deployment
        template: deploy-model
        depends: model-evaluation
        
  # Data preprocessing step
  - name: preprocess-data
    container:
      image: python:3.9-slim
      command: [python]
      source: |
        import pandas as pd
        import numpy as np
        
        # Load and preprocess data
        print("Loading data...")
        # Your preprocessing logic here
        print("Data preprocessing completed!")
      volumeMounts:
      - name: data-volume
        mountPath: /data
      env:
      - name: MLFLOW_TRACKING_URI
        value: "http://mlflow.mlflow:5000"
        
  # Model training step  
  - name: train-model
    container:
      image: python:3.9-slim
      command: [python]
      source: |
        import mlflow
        import mlflow.sklearn
        from sklearn.ensemble import RandomForestClassifier
        
        mlflow.set_tracking_uri("http://mlflow.mlflow:5000")
        
        with mlflow.start_run():
            # Training logic
            model = RandomForestClassifier(n_estimators=100)
            # model.fit(X_train, y_train)
            
            mlflow.log_param("n_estimators", 100)
            mlflow.sklearn.log_model(model, "model")
            print("Model training completed!")
      env:
      - name: MLFLOW_S3_ENDPOINT_URL
        value: "http://minio.minio:9000"
      - name: AWS_ACCESS_KEY_ID
        valueFrom:
          secretKeyRef:
            name: minio-credentials-wf
            key: AWS_ACCESS_KEY_ID
      - name: AWS_SECRET_ACCESS_KEY
        valueFrom:
          secretKeyRef:
            name: minio-credentials-wf
            key: AWS_SECRET_ACCESS_KEY
            
  # Model evaluation step
  - name: evaluate-model
    container:
      image: python:3.9-slim
      command: [python]
      source: |
        import mlflow
        
        mlflow.set_tracking_uri("http://mlflow.mlflow:5000")
        
        # Load latest model and evaluate
        print("Evaluating model...")
        # Your evaluation logic here
        print("Model evaluation completed!")
        
  # Model deployment step
  - name: deploy-model
    container:
      image: curlimages/curl
      command: [sh, -c]
      args:
      - |
        echo "Deploying model to Seldon Core..."
        # Your deployment logic here
        echo "Model deployment completed!"
```

### **Workflow Templates (Reusable Components)**
```yaml
apiVersion: argoproj.io/v1alpha1
kind: WorkflowTemplate
metadata:
  name: ml-training-template
  namespace: argowf
spec:
  templates:
  - name: python-ml-task
    inputs:
      parameters:
      - name: script
      - name: requirements
        value: "pandas numpy scikit-learn mlflow"
    container:
      image: python:3.9-slim
      command: [sh, -c]
      args:
      - |
        pip install {{inputs.parameters.requirements}}
        python -c "{{inputs.parameters.script}}"
      env:
      - name: MLFLOW_TRACKING_URI
        value: "http://mlflow.mlflow:5000"
```

### **Cron Workflows (Scheduled Execution)**
```yaml
apiVersion: argoproj.io/v1alpha1
kind: CronWorkflow
metadata:
  name: model-retraining-cron
  namespace: argowf
spec:
  schedule: "0 2 * * 0"  # Weekly on Sunday at 2 AM
  timezone: "America/New_York"
  workflowSpec:
    entrypoint: retrain-model
    templates:
    - name: retrain-model
      container:
        image: python:3.9-slim
        command: [python]
        source: |
          print("Starting scheduled model retraining...")
          # Your retraining logic here
```

## 🔄 **Integration with MLOps Stack**

### **MLflow Integration**
```python
# Inside workflow containers
import mlflow
import os

# Configure MLflow
mlflow.set_tracking_uri("http://mlflow.mlflow:5000")
os.environ['MLFLOW_S3_ENDPOINT_URL'] = 'http://minio.minio:9000'

# Use in workflow steps
with mlflow.start_run():
    # Your ML code
    mlflow.log_metric("accuracy", 0.95)
```

### **MinIO Storage Integration**
```yaml
# Workflow with MinIO access
env:
- name: AWS_ACCESS_KEY_ID
  valueFrom:
    secretKeyRef:
      name: minio-credentials-wf
      key: AWS_ACCESS_KEY_ID
- name: AWS_SECRET_ACCESS_KEY
  valueFrom:
    secretKeyRef:
      name: minio-credentials-wf
      key: AWS_SECRET_ACCESS_KEY
- name: AWS_ENDPOINT_URL
  value: "http://minio.minio:9000"
```

### **Seldon Core Model Deployment**
```yaml
# Deploy model after training
- name: deploy-to-seldon
  container:
    image: curlimages/curl
    command: [sh, -c]
    args:
    - |
      cat <<EOF | kubectl apply -f -
      apiVersion: machinelearning.seldon.io/v1
      kind: SeldonDeployment
      metadata:
        name: iris-model
        namespace: default
      spec:
        predictors:
        - graph:
            implementation: MLFLOW_SERVER
            modelUri: s3://mlflow-artifacts/model
          name: default
      EOF
```

## 📊 **Monitoring & Management**

### **Workflow Status Monitoring**
```bash
# Monitor running workflows
argo list -n argowf --running

# Get workflow metrics
argo get iris-demo -n argowf -o json | jq '.status'

# Watch workflow in real-time
argo watch iris-demo -n argowf

# Get workflow logs with timestamps
argo logs iris-demo -n argowf --timestamps
```

### **Resource Usage Tracking**
```bash
# Check workflow resource usage
kubectl top pods -n argowf

# Monitor workflow controller
kubectl logs deployment/argo-workflows-workflow-controller -n argowf

# Check server logs
kubectl logs deployment/argo-workflows-server -n argowf
```

### **Cleanup and Maintenance**
```bash
# Delete completed workflows
argo delete --completed -n argowf

# Delete workflows older than 7 days
argo delete --older 7d -n argowf

# Clean up all workflows (be careful!)
argo delete --all -n argowf
```

## 🚀 **Advanced Features**

### **Workflow Parameters**
```yaml
# Parameterized workflows
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: parameterized-workflow-
spec:
  entrypoint: main
  arguments:
    parameters:
    - name: model-type
      value: "random-forest"
    - name: n-estimators  
      value: "100"
  templates:
  - name: main
    inputs:
      parameters:
      - name: model-type
      - name: n-estimators
    container:
      image: python:3.9-slim
      command: [python]
      args: ["-c", "print('Training {{inputs.parameters.model-type}} with {{inputs.parameters.n-estimators}} estimators')"]
```

### **Conditional Execution**
```yaml
# Conditional steps based on results
- name: conditional-deploy
  dag:
    tasks:
    - name: evaluate
      template: evaluate-model
    - name: deploy
      template: deploy-model
      depends: evaluate.Succeeded
      when: "{{tasks.evaluate.outputs.parameters.accuracy}} > 0.9"
```

### **Workflow Event Handling**
```yaml
# Webhooks and event triggers
apiVersion: argoproj.io/v1alpha1
kind: Sensor
metadata:
  name: model-training-sensor
spec:
  triggers:
  - template:
      name: model-training-trigger
      argoWorkflow:
        source:
          resource:
            apiVersion: argoproj.io/v1alpha1
            kind: Workflow
            metadata:
              generateName: triggered-training-
```

## 🛡️ **Security & RBAC**

### **Service Account Configuration**
```yaml
# Workflow with custom service account
spec:
  serviceAccountName: ml-workflow-sa
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
```

### **Secret Management**
```yaml
# Using Kubernetes secrets in workflows
env:
- name: API_KEY
  valueFrom:
    secretKeyRef:
      name: ml-api-secrets
      key: api-key
```

## 🐛 **Troubleshooting**

### **Common Issues**

#### **Workflow Stuck in Pending**
```bash
# Check node resources
kubectl top nodes

# Check workflow events
kubectl describe workflow iris-demo -n argowf

# Check pod scheduling
kubectl get pods -n argowf -o wide
```

#### **Container Image Pull Errors**
```bash
# Check image pull secrets
kubectl get secrets -n argowf

# Verify image exists
docker pull your-image:tag

# Check registry connectivity
kubectl run test-pod --image=your-image:tag --rm -it
```

#### **Permission Denied Errors**
```bash
# Check service account permissions
kubectl auth can-i create pods --as=system:serviceaccount:argowf:default

# Check RBAC
kubectl get rolebindings -n argowf
kubectl get clusterrolebindings | grep argo
```

### **Debug Commands**
```bash
# Get detailed workflow information
argo get iris-demo -n argowf -o yaml

# Check workflow controller logs
kubectl logs deployment/argo-workflows-workflow-controller -n argowf --tail=100

# Debug specific workflow step
kubectl logs iris-demo-train-123456 -n argowf
```

## 📈 **Best Practices**

### **Workflow Design**
- **Modular Templates**: Create reusable workflow templates
- **Resource Limits**: Set appropriate CPU/memory limits
- **Timeout Configuration**: Set timeouts for long-running tasks
- **Error Handling**: Implement proper error handling and retries

### **Performance Optimization**
- **Node Affinity**: Use node selectors for optimal placement
- **Parallel Execution**: Leverage DAG templates for parallelism
- **Resource Pooling**: Share resources between workflow steps
- **Caching**: Cache intermediate results when possible

### **MLOps Integration**
- **Experiment Tracking**: Always log to MLflow
- **Artifact Management**: Store all artifacts in MinIO
- **Model Versioning**: Use semantic versioning for models
- **Pipeline Versioning**: Version your workflow templates

## 🔗 **API Reference**

### **REST API Endpoints**
```bash
# Get workflow list
curl http://192.168.1.85:32746/api/v1/workflows/argowf

# Get specific workflow
curl http://192.168.1.85:32746/api/v1/workflows/argowf/iris-demo

# Submit workflow
curl -X POST http://192.168.1.85:32746/api/v1/workflows/argowf/submit \
  -H "Content-Type: application/json" \
  -d @workflow.json
```

### **CLI Commands Reference**
```bash
# Essential argo CLI commands
argo submit <workflow.yaml> -n argowf      # Submit workflow
argo list -n argowf                        # List workflows  
argo get <workflow-name> -n argowf         # Get workflow details
argo logs <workflow-name> -n argowf        # Get logs
argo watch <workflow-name> -n argowf       # Watch progress
argo delete <workflow-name> -n argowf      # Delete workflow
argo retry <workflow-name> -n argowf       # Retry failed workflow
argo suspend <workflow-name> -n argowf     # Suspend workflow
argo resume <workflow-name> -n argowf      # Resume workflow
```

---

## 🎯 **Next Steps**

1. **Explore Examples**: Try the [iris-workflow example](../../homelab-mlops-demo-June13/manifests/workflows/)
2. **Create Templates**: Build reusable workflow templates
3. **Set up Monitoring**: Track workflows in [Grafana](http://192.168.1.85:30300)
4. **Integration**: Connect with [MLflow](http://192.168.1.85:30800) and [ArgoCD](http://192.168.1.85:30080)

**Argo Workflows powers your ML pipelines - master it for automated MLOps!** 🚀

---

## 📚 **Additional Resources**

- [Official Argo Workflows Documentation](https://argoproj.github.io/argo-workflows/)
- [Workflow Examples Repository](https://github.com/argoproj/argo-workflows/tree/master/examples)
- [MLOps Pipeline Patterns](https://ml-ops.org/content/phase-three)
- [Kubernetes Workflow Best Practices](https://kubernetes.io/docs/concepts/workloads/)
