# MLflow Tracking Server Role

This Ansible role deploys MLflow tracking server with **PostgreSQL backend** and **Harbor registry integration** for production ML lifecycle management.

## Overview

MLflow is an open-source platform for managing the ML lifecycle, including experimentation, reproducibility, deployment, and a central model registry. This role deploys a production-ready MLflow instance with external PostgreSQL backend and high-resource allocation.

## Architecture

```
🏗️ MLflow Production Architecture
├── 📦 MLflow Server (Harbor Image)
│   ├── 192.168.1.210/library/mlflow-postgresql:3.1.0-4
│   ├── Experiment Tracking API
│   ├── Model Registry
│   └── Basic Authentication
├── 🗄️ Storage Layer
│   ├── 🐘 External PostgreSQL Database (Primary)
│   │   ├── Backend Store: postgresql://192.168.1.100:5432
│   │   ├── Experiments & Runs metadata
│   │   └── Model Registry data
│   └── 📦 S3 Artifacts (MinIO)
│       └── Model artifacts & files
├── 🔐 Security
│   ├── Harbor Registry Authentication
│   ├── Basic Auth (username/password)
│   ├── Sealed Secrets (DB + S3 credentials)
│   └── Namespace isolation
└── 🌐 Service Access
    ├── NodePort: 30800
    └── LoadBalancer: 192.168.1.201:5000 (MetalLB)
```

## Features

- ✅ **Experiment Tracking** - Log parameters, metrics, and artifacts
- ✅ **Model Registry** - Version and manage ML models
- ✅ **S3 Backend** - Secure artifact storage via MinIO
- ✅ **Sealed Secrets** - GitOps-ready credential management
- ✅ **PostgreSQL Backend** - External PostgreSQL database
- ✅ **External Access** - NodePort service for web UI
- ✅ **Production Ready** - Resource limits and health checks

## Requirements

### Dependencies
- Kubernetes cluster with CSI storage
- Sealed Secrets controller deployed
- MinIO deployed and accessible
- Ansible collections:
  - `kubernetes.core`

### Variables
| Variable | Default | Description |
|----------|---------|-------------|
| `mlflow_namespace` | `mlflow` | Kubernetes namespace |
| `mlflow_image` | `192.168.1.210/library/mlflow-postgresql:3.1.0-4` | Harbor registry image |
| `mlflow_memory_request` | `8Gi` | Memory request |
| `mlflow_memory_limit` | `16Gi` | Memory limit |
| `mlflow_cpu_request` | `2` | CPU request |
| `mlflow_cpu_limit` | `4` | CPU limit |
| `mlflow_db_host` | `192.168.1.100` | PostgreSQL server host |
| `mlflow_db_port` | `5432` | PostgreSQL server port |
| `mlflow_db_name` | `mlflow` | PostgreSQL database name |
| `mlflow_authdb_name` | `mlflow_auth` | Authentication database |
| `mlflow_s3_bucket` | `mlflow-artifacts` | S3 bucket for artifacts |
| `mlflow_s3_endpoint` | `http://minio.minio.svc.cluster.local:9000` | MinIO endpoint URL |
| `kubeconfig_path` | - | Path to kubeconfig file |

## Deployment

### 1. Prerequisites
Ensure sealed secrets are created:
```bash
./scripts/create-all-sealed-secret.sh
```

### 2. Deploy MLflow
```bash
# Deploy complete MLflow stack
ansible-playbook -i inventory/production/hosts infrastructure/cluster/site.yml --tags="mlflow"

# Deploy only specific components
ansible-playbook site.yml --tags="mlflow,deployment"  # Just the deployment
ansible-playbook site.yml --tags="mlflow,storage"     # Just storage components
ansible-playbook site.yml --tags="mlflow,service"     # Just the service
```

### 3. Verify Deployment
```bash
# Check deployment status
kubectl get all -n mlflow

# Check logs
kubectl logs -n mlflow deployment/mlflow

# Test connectivity
curl http://192.168.1.201:5000/health
```

## Usage

### Web Interface
- **URL**: `http://192.168.1.201:5000` (LoadBalancer) or `http://192.168.1.85:30800` (NodePort)
- **Features**: View experiments, runs, models, artifacts
- **Authentication**: Basic auth (username/password via sealed secrets)

### Python API

#### External Access (from outside cluster)
```python
import mlflow
import os

# Set authentication credentials
os.environ['MLFLOW_TRACKING_USERNAME'] = 'your-username'
os.environ['MLFLOW_TRACKING_PASSWORD'] = 'your-password'

# Set tracking URI (LoadBalancer endpoint)
mlflow.set_tracking_uri("http://192.168.1.201:5000")

# Alternative: NodePort endpoint
# mlflow.set_tracking_uri("http://192.168.1.85:30800")

# Verify connection
print(f"MLflow Tracking URI: {mlflow.get_tracking_uri()}")
```

#### Internal Access (from within cluster)
```python
import mlflow

# Use internal service DNS
mlflow.set_tracking_uri("http://mlflow.mlflow.svc.cluster.local:5000")
```

#### Complete Example
```python
import mlflow
import mlflow.sklearn
import os
from sklearn.ensemble import RandomForestClassifier
from sklearn.datasets import load_iris
from sklearn.model_selection import train_test_split
from sklearn.metrics import accuracy_score

# Set authentication credentials
os.environ['MLFLOW_TRACKING_USERNAME'] = 'your-username'
os.environ['MLFLOW_TRACKING_PASSWORD'] = 'your-password'

# Set tracking URI
mlflow.set_tracking_uri("http://192.168.1.201:5000")

# Create experiment
mlflow.set_experiment("iris-classification")

# Start MLflow run
with mlflow.start_run():
    # Load data
    iris = load_iris()
    X_train, X_test, y_train, y_test = train_test_split(
        iris.data, iris.target, test_size=0.2, random_state=42
    )
    
    # Train model
    rf = RandomForestClassifier(n_estimators=100, random_state=42)
    rf.fit(X_train, y_train)
    
    # Make predictions
    y_pred = rf.predict(X_test)
    accuracy = accuracy_score(y_test, y_pred)
    
    # Log parameters
    mlflow.log_param("n_estimators", 100)
    mlflow.log_param("random_state", 42)
    
    # Log metrics
    mlflow.log_metric("accuracy", accuracy)
    
    # Log model
    mlflow.sklearn.log_model(rf, "model")
    
    print(f"Accuracy: {accuracy}")
    print(f"Run ID: {mlflow.active_run().info.run_id}")
```

## Configuration

### Sealed Secrets
MLflow uses multiple sealed secrets for secure credential management:

```yaml
# S3/MinIO credentials
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: mlflow-s3-secret
  namespace: mlflow
spec:
  encryptedData:
    AWS_ACCESS_KEY_ID: AgBy3i4OJSWK+PiTySYZZA9rO5QtQFe...
    AWS_SECRET_ACCESS_KEY: AgAKAoiRBcKSadhajwGzA9rQ5QtQeL...

# Basic authentication credentials
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: mlflow-basic-auth
  namespace: mlflow
spec:
  encryptedData:
    MLFLOW_TRACKING_USERNAME: AgCT7gVdP3xJ2YHxB4tN8vCf2Q...
    MLFLOW_TRACKING_PASSWORD: AgCT7gVdP3xJ2YHxB4tN8vCf2Q...
    MLFLOW_FLASK_SERVER_SECRET_KEY: AgCT7gVdP3xJ2YHxB4tN8vCf2Q...

# PostgreSQL database credentials
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: mlflow-db-credentials
  namespace: mlflow
spec:
  encryptedData:
    username: AgCT7gVdP3xJ2YHxB4tN8vCf2Q...
    password: AgCT7gVdP3xJ2YHxB4tN8vCf2Q...
```

### Environment Variables
The deployment uses these environment variables:
- `MLFLOW_S3_ENDPOINT_URL`: MinIO endpoint URL
- `AWS_ACCESS_KEY_ID`: S3 access key (from sealed secret)
- `AWS_SECRET_ACCESS_KEY`: S3 secret key (from sealed secret)
- `MLFLOW_TRACKING_USERNAME`: Basic auth username (from sealed secret)
- `MLFLOW_TRACKING_PASSWORD`: Basic auth password (from sealed secret)
- `MLFLOW_DB_USERNAME`: PostgreSQL username (from sealed secret)
- `MLFLOW_DB_PASSWORD`: PostgreSQL password (from sealed secret)
- `MLFLOW_FLASK_SERVER_SECRET_KEY`: Flask session encryption key

### Storage
- **Database**: External PostgreSQL at `192.168.1.100:5432/mlflow`
- **Authentication Database**: PostgreSQL at `192.168.1.100:5432/mlflow_auth`
- **Artifacts**: S3-compatible storage (MinIO bucket: `mlflow-artifacts`)
- **Credentials**: Managed via sealed secrets

## File Structure

```
infrastructure/cluster/roles/mlflow/
├── tasks/
│   └── main.yml                 # Main deployment tasks
├── templates/
│   ├── deployment.yaml.j2       # MLflow deployment template
│   ├── service.yaml.j2          # NodePort service template
│   └── pvc.yaml.j2              # Persistent volume claim
└── README.md                    # This file
```

## Troubleshooting

### Common Issues

#### 1. Pod CrashLoopBackOff
```bash
# Check logs
kubectl logs -n mlflow deployment/mlflow

# Common causes:
# - Missing sealed secret
# - S3 connectivity issues
# - Invalid environment variables
```

#### 2. S3 Connection Errors
```bash
# Verify MinIO is accessible
kubectl get svc -n minio

# Check S3 credentials in sealed secret
kubectl get secret -n mlflow mlflow-s3-secret -o yaml
```

#### 3. DNS Resolution Issues
```bash
# Test DNS from MLflow pod
kubectl exec -n mlflow deployment/mlflow -- nslookup minio.minio.svc.cluster.local

# Check CoreDNS
kubectl get pods -n kube-system | grep coredns
```

### Health Checks
```bash
# Check all MLflow resources
kubectl get all -n mlflow

# Test API endpoint
curl -u username:password http://192.168.1.201:5000/api/2.0/mlflow/experiments/search

# Check auth configuration
kubectl exec -n mlflow deployment/mlflow -- cat /tmp/auth_config_resolved.ini
```

## Integration

### JupyterHub Integration
MLflow is pre-configured to work with JupyterHub:
```python
# From JupyterHub notebooks, use internal DNS
mlflow.set_tracking_uri("http://mlflow.mlflow.svc.cluster.local:5000")
```

### Argo Workflows Integration
Reference MLflow in workflow templates:
```yaml
# In Argo Workflow templates
env:
- name: MLFLOW_TRACKING_URI
  value: "http://mlflow.mlflow.svc.cluster.local:5000"
```

## Security Considerations

- ✅ **Sealed Secrets**: S3 credentials encrypted at rest
- ✅ **Namespace Isolation**: Deployed in dedicated namespace
- ✅ **Resource Limits**: CPU and memory constraints
- ⚠️ **Open Access**: No authentication (suitable for homelab)
- ⚠️ **HTTP Only**: No TLS encryption (internal network)

## Monitoring

MLflow integrates with the platform monitoring stack:
- **Prometheus**: Metrics collection from MLflow pods
- **Grafana**: Dashboards for MLflow performance
- **Logs**: Centralized logging via cluster logging

## Backup and Recovery

### Database Backup
```bash
# Backup PostgreSQL database
pg_dump -h 192.168.1.100 -U mlflow_user -d mlflow > mlflow-backup.sql
pg_dump -h 192.168.1.100 -U mlflow_user -d mlflow_auth > mlflow-auth-backup.sql
```

### Artifact Backup
Artifacts are stored in MinIO - refer to MinIO backup procedures.

## Updates and Maintenance

### Update MLflow Version
1. Update image version in `templates/deployment.yaml.j2`
2. Test in development environment
3. Deploy with rolling update:
```bash
ansible-playbook site.yml --tags="mlflow,deployment"
```

### Scale MLflow
```bash
# Scale replicas (supported with PostgreSQL backend)
kubectl scale deployment mlflow -n mlflow --replicas=2
```

## Contributing

When modifying this role:
1. Update templates in `templates/` directory
2. Test changes with `--check` and `--diff` flags
3. Update this README with any new features
4. Tag deployments appropriately

## Links

- [MLflow Documentation](https://mlflow.org/docs/latest/)
- [MLflow Python API](https://mlflow.org/docs/latest/python_api/)
- [MLflow REST API](https://mlflow.org/docs/latest/rest-api.html)
- [MinIO Integration](https://docs.min.io/docs/how-to-use-aws-sdk-for-python-with-minio-server.html)

---

**Part of the K3s Homelab MLOps Platform** | [Main Documentation](../../README.md)