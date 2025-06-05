# 📊 MLflow Configuration & Usage

Complete guide to using MLflow for experiment tracking and model management.

## 🚀 **Quick Access**
- **URL**: [http://192.168.1.85:30800](http://192.168.1.85:30800)
- **Authentication**: None (internal network)
- **Storage Backend**: MinIO S3-compatible storage
- **Database**: SQLite (upgradeable to PostgreSQL)

## 🔧 **Configuration**

### **MLflow Server Setup**
```yaml
# Current configuration
backend_store_uri: sqlite:///mlflow/mlflow.db
default_artifact_root: s3://mlflow-artifacts/
serve_artifacts: true
host: 0.0.0.0
port: 5000
```

### **S3 Integration with MinIO**
```python
import os
os.environ['MLFLOW_S3_ENDPOINT_URL'] = 'http://192.168.1.85:30900'
os.environ['AWS_ACCESS_KEY_ID'] = 'minioadmin'
os.environ['AWS_SECRET_ACCESS_KEY'] = 'minioadmin123'
```

## 🧪 **Usage Examples**

### **Basic Experiment Tracking**
```python
import mlflow
import mlflow.sklearn
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import accuracy_score

# Set MLflow tracking URI
mlflow.set_tracking_uri("http://192.168.1.85:30800")

# Start an MLflow run
with mlflow.start_run():
    # Train model
    model = RandomForestClassifier(n_estimators=100, random_state=42)
    model.fit(X_train, y_train)
    
    # Make predictions
    predictions = model.predict(X_test)
    accuracy = accuracy_score(y_test, predictions)
    
    # Log parameters
    mlflow.log_param("n_estimators", 100)
    mlflow.log_param("random_state", 42)
    
    # Log metrics
    mlflow.log_metric("accuracy", accuracy)
    
    # Log model
    mlflow.sklearn.log_model(model, "random_forest_model")
    
    # Log artifacts
    mlflow.log_artifact("feature_importance.png")
```

### **Model Registry Usage**
```python
# Register model
model_uri = "runs:/<run_id>/random_forest_model"
model_details = mlflow.register_model(model_uri, "RandomForestClassifier")

# Transition model to production
client = mlflow.tracking.MlflowClient()
client.transition_model_version_stage(
    name="RandomForestClassifier",
    version=1,
    stage="Production"
)

# Load production model
model = mlflow.pyfunc.load_model(
    model_uri=f"models:/RandomForestClassifier/Production"
)
```

### **Integration with Jupyter Notebooks**
```python
# In JupyterHub notebook (http://192.168.1.85:30888)
import mlflow
import pandas as pd

# Configure MLflow
mlflow.set_tracking_uri("http://192.168.1.85:30800")
mlflow.set_experiment("customer_churn_analysis")

# Your ML workflow
with mlflow.start_run():
    # Data loading
    data = pd.read_csv("s3://datasets/customer_data.csv")
    mlflow.log_param("dataset_size", len(data))
    
    # Feature engineering
    features = create_features(data)
    mlflow.log_artifact("feature_summary.html")
    
    # Model training
    model = train_model(features)
    mlflow.sklearn.log_model(model, "model")
    
    # Evaluation
    metrics = evaluate_model(model, test_data)
    for metric_name, value in metrics.items():
        mlflow.log_metric(metric_name, value)
```

## 🔄 **Integration with Argo Workflows**

### **MLflow in Pipeline Steps**
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  name: ml-training-pipeline
spec:
  templates:
  - name: train-model
    container:
      image: python:3.9
      command: [python]
      source: |
        import mlflow
        import mlflow.sklearn
        
        mlflow.set_tracking_uri("http://mlflow.mlflow:5000")
        
        with mlflow.start_run():
            # Training logic
            model = train_model()
            mlflow.sklearn.log_model(model, "model")
      env:
      - name: MLFLOW_S3_ENDPOINT_URL
        value: "http://minio.minio:9000"
      - name: AWS_ACCESS_KEY_ID
        value: "minioadmin"  
      - name: AWS_SECRET_ACCESS_KEY
        value: "minioadmin123"
```

## 📊 **Monitoring & Maintenance**

### **Health Checks**
```bash
# Check MLflow service status
kubectl get pods -n mlflow
kubectl logs deployment/mlflow -n mlflow

# Test MLflow API
curl http://192.168.1.85:30800/health

# Check storage connectivity
curl http://192.168.1.85:30900/minio/health/live
```

### **Database Maintenance**
```bash
# Backup MLflow database
kubectl exec deployment/mlflow -n mlflow -- \
  sqlite3 /mlflow/mlflow.db .backup /tmp/mlflow_backup.db

# Copy backup locally
kubectl cp mlflow/mlflow-pod:/tmp/mlflow_backup.db ./mlflow_backup.db
```

### **Storage Management**
```bash
# Check artifact storage usage
kubectl exec deployment/minio -n minio -- \
  mc du --json local/mlflow-artifacts

# Clean up old experiments (be careful!)
# Use MLflow UI or API to delete experiments
```

## 🚀 **Advanced Configuration**

### **Upgrade to PostgreSQL Backend**
```yaml
# For production workloads
backend_store_uri: postgresql://user:pass@postgres:5432/mlflow
```

### **Enable Authentication**
```yaml
# Add auth configuration
auth_config_path: /mlflow/auth.ini
```

### **Custom Artifact Storage**
```yaml
# Configure different storage backends
default_artifact_root: gs://my-gcs-bucket/  # Google Cloud Storage
default_artifact_root: hdfs://namenode:port/path/  # HDFS
```

## 🐛 **Troubleshooting**

### **Common Issues**

#### **Can't Connect to MLflow**
```bash
# Check pod status
kubectl get pods -n mlflow

# Check service
kubectl get svc -n mlflow

# Test from within cluster
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
  curl http://mlflow.mlflow:5000/health
```

#### **S3 Connection Failed**
```bash
# Verify MinIO connectivity
kubectl exec deployment/mlflow -n mlflow -- \
  curl http://minio.minio:9000/minio/health/live

# Check environment variables
kubectl exec deployment/mlflow -n mlflow -- env | grep AWS
```

#### **Artifact Upload Failed**
```bash
# Check MinIO bucket exists
kubectl exec deployment/minio -n minio -- \
  mc ls local/mlflow-artifacts

# Create bucket if missing
kubectl exec deployment/minio -n minio -- \
  mc mb local/mlflow-artifacts
```

## 📈 **Best Practices**

### **Experiment Organization**
- Use descriptive experiment names
- Tag experiments with project/team info
- Set up experiment permissions
- Regular cleanup of old experiments

### **Model Management**
- Use semantic versioning for models
- Document model changes in descriptions
- Set up model approval workflows
- Monitor model performance metrics

### **Performance Optimization**
- Use appropriate database backend for scale
- Configure artifact storage lifecycle
- Monitor storage usage and costs
- Optimize query performance

---

## 🎯 **Next Steps**

1. **Explore the UI**: [MLflow Dashboard](http://192.168.1.85:30800)
2. **Run Example**: Try the notebook examples in [JupyterHub](http://192.168.1.85:30888)
3. **Set up Pipelines**: Create automated workflows with [Argo](http://192.168.1.85:32746)
4. **Monitor Usage**: Track metrics in [Grafana](http://192.168.1.85:30300)

**MLflow is the heart of your MLOps platform - master it for maximum impact!** 🎯
