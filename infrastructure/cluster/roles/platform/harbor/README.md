# Harbor Container Registry Role

## Overview

This Ansible role deploys Harbor container registry for the MLOps platform, providing secure image storage, vulnerability scanning, and content signing capabilities.

## Features

- **Container Registry**: Docker-compatible registry for private images
- **Vulnerability Scanning**: Trivy integration for security analysis
- **Content Trust**: Notary service for image signing
- **Helm Charts**: ChartMuseum for Helm chart repository
- **RBAC**: Role-based access control for projects and repositories
- **Replication**: Cross-registry replication support
- **MetalLB Integration**: LoadBalancer support for production access

## Architecture

```
harbor namespace:
├── harbor-core (API server)
├── harbor-registry (Docker registry backend)
├── harbor-database (PostgreSQL)
├── harbor-redis (Cache)
├── harbor-trivy (Vulnerability scanner)
├── harbor-notary (Content signing)
└── harbor-chartmuseum (Helm charts)
```

## Configuration

### Default Variables

```yaml
# Namespace and service configuration
harbor_namespace: "harbor"
harbor_nodeport: 30880
harbor_loadbalancer_ip: "192.168.1.210"

# Authentication
harbor_admin_password: "Harbor12345"
harbor_secret_key: "not-a-secure-key"

# Storage
harbor_storage_size: "50Gi"
harbor_registry_storage_size: "200Gi"
harbor_storage_class: "local-path"

# Features
harbor_trivy_enabled: true
harbor_notary_enabled: true
harbor_chartmuseum_enabled: true

# Security
harbor_tls_enabled: false

# Integration
harbor_integrate_with_seldon: true
harbor_integrate_with_jupyter: true
```

### Inventory Configuration

Key variables in `inventory/production/group_vars/all.yml`:

```yaml
# Harbor registry settings
harbor_admin_password: "your-secure-password"
harbor_loadbalancer_ip: "192.168.1.210"

# Integration settings
harbor_integrate_with_seldon: true
harbor_integrate_with_jupyter: true
```

## Features

### Security Features
- **Vulnerability Scanning**: Automated Trivy scans on push
- **Content Trust**: Image signing with Notary
- **RBAC**: Project-level access control
- **Audit Logging**: Complete audit trail

### Registry Features
- **Docker API**: Full Docker registry v2 API compatibility
- **Helm Charts**: Store and serve Helm charts
- **Replication**: Sync with external registries
- **Webhooks**: Integration with CI/CD pipelines

### Platform Integration
- **Seldon Core**: Automatic registry secrets creation
- **JupyterHub**: Registry access for notebook environments
- **Kubernetes**: Service account pull secrets

## Usage

### Basic Deployment

```bash
# Deploy Harbor with default settings
ansible-playbook -i inventory/production/hosts infrastructure/cluster/site.yml --tags harbor

# Deploy with MetalLB LoadBalancer
ansible-playbook -i inventory/production/hosts infrastructure/cluster/site.yml --tags harbor -e metallb_state=present
```

### Post-Deployment

1. **Access Harbor UI**:
   ```bash
   # With LoadBalancer
   open http://192.168.1.210
   
   # With NodePort
   open http://<node-ip>:30880
   ```

2. **Login Credentials**:
   - Username: `admin`
   - Password: Value of `harbor_admin_password`

3. **Verify Installation**:
   ```bash
   kubectl get pods -n harbor
   kubectl get svc -n harbor
   ```

### Docker Usage

```bash
# Login to Harbor
docker login 192.168.1.210 -u admin -p Harbor12345

# Tag and push image
docker tag myapp:latest 192.168.1.210/library/myapp:latest
docker push 192.168.1.210/library/myapp:latest

# Pull image
docker pull 192.168.1.210/library/myapp:latest
```

### Kubernetes Integration

Harbor automatically creates registry secrets for integrated namespaces:

```bash
# Check registry secrets
kubectl get secrets -n seldon-system | grep harbor-registry-secret
kubectl get secrets -n jupyterhub | grep harbor-registry-secret

# Use in deployments
apiVersion: apps/v1
kind: Deployment
spec:
  template:
    spec:
      imagePullSecrets:
      - name: harbor-registry-secret
      containers:
      - name: app
        image: 192.168.1.210/library/myapp:latest
```

## Project Management

### Create Projects via UI

1. Navigate to Harbor UI: `http://192.168.1.210`
2. Login with admin credentials
3. Click "Projects" → "New Project"
4. Configure project settings:
   - Project Name: e.g., `ml-models`
   - Access Level: Private/Public
   - Enable Vulnerability Scanning

### Project Examples

```yaml
# Common project structure
library/          # Default public project
├── mlflow-postgresql:3.1.0-4
├── seldon-scheduler:2.9.1
└── seldon-controller:fix-namespace-lookup-v4

ml-models/        # Private ML models project
├── fraud-detector:v1.0
├── risk-model:v2.1
└── recommendation-engine:v1.5

base-images/      # Common base images
├── python-ml:3.9
├── pytorch:1.12
└── tensorflow:2.8
```

## Vulnerability Scanning

Harbor includes Trivy for automatic vulnerability scanning:

### Configuration
```yaml
harbor_trivy_enabled: true
harbor_enable_scan_webhooks: true
```

### Usage
- **Automatic Scanning**: Images scanned on push
- **Manual Scanning**: Trigger scans via UI or API
- **Scan Reports**: Detailed vulnerability reports
- **Policy Enforcement**: Block vulnerable images

### Webhook Integration
Harbor can send scan results to monitoring systems:

```bash
# Webhook endpoint (configured automatically)
http://192.168.1.209:9091/metrics/job/harbor_scan
```

## Replication

Harbor supports replication to/from external registries:

### Configuration
```yaml
harbor_enable_replication: true
harbor_enable_automated_sync: true
```

### Replication Rules
The role configures replication rules in `harbor-replication-config.yaml`:

```yaml
replication:
  tier1:
    - source: docker.io/seldonio/mlserver
      destination: library/mlserver
    - source: docker.io/seldonio/seldon-agent
      destination: library/seldon-agent
```

### Sync Process
```bash
# Manual sync
/opt/harbor-sync/harbor-sync.sh --tier tier1 --now

# Automated sync (systemd timer)
systemctl status harbor-sync.timer
```

## Storage

### Persistent Volumes
Harbor requires persistent storage for:

```yaml
# Automatically created PVCs
harbor-database-pvc:    # PostgreSQL data
harbor-registry-pvc:    # Container images  
harbor-redis-pvc:       # Cache data
```

### Storage Configuration
```yaml
# Storage settings
harbor_storage_class: "local-path"
harbor_storage_size: "50Gi"          # Database and config
harbor_registry_storage_size: "200Gi" # Container images
```

## Troubleshooting

### Common Issues

1. **Harbor UI Not Accessible**
   ```bash
   # Check service status
   kubectl get svc -n harbor harbor
   
   # Check pod status
   kubectl get pods -n harbor
   kubectl logs -n harbor harbor-core-<pod-id>
   ```

2. **Image Push Failures**
   ```bash
   # Check registry service
   kubectl logs -n harbor harbor-registry-<pod-id>
   
   # Verify credentials
   docker login 192.168.1.210 -u admin -p Harbor12345
   ```

3. **Persistent Volume Issues**
   ```bash
   # Check PVC status
   kubectl get pvc -n harbor
   
   # Check storage class
   kubectl get storageclass
   ```

4. **Database Connection Issues**
   ```bash
   # Check PostgreSQL pod
   kubectl logs -n harbor harbor-database-<pod-id>
   
   # Test database connectivity
   kubectl exec -n harbor harbor-core-<pod-id> -- pg_isready -h harbor-database
   ```

### Debug Commands

```bash
# Check all Harbor resources
kubectl get all -n harbor

# View Harbor core logs
kubectl logs -n harbor deployment/harbor-core

# Check registry backend
kubectl logs -n harbor deployment/harbor-registry

# Test registry API
curl -u admin:Harbor12345 http://192.168.1.210/api/v2.0/projects
```

## Security Considerations

1. **Change Default Passwords**: Update `harbor_admin_password`
2. **Enable TLS**: Set `harbor_tls_enabled: true` and configure TLS certificates for HTTPS (disabled by default for containerd compatibility)
3. **Network Policies**: Restrict access to Harbor services
4. **Vulnerability Scanning**: Enable and monitor scan results
5. **Content Trust**: Enable Notary for image signing

## Best Practices

### Project Organization
```
library/          # Public base images and tools
├── python:3.9
├── ubuntu:20.04
└── mlflow:latest

ml-models/        # Private ML models (project-specific)
├── fraud-detector:v1.0
└── risk-model:v2.0

infrastructure/   # Platform images
├── seldon-controller:v2.9.1
└── istio-proxy:1.26.2
```

### Image Tagging
```bash
# Use semantic versioning
harbor.test/ml-models/fraud-detector:1.0.0
harbor.test/ml-models/fraud-detector:1.0.1

# Include build metadata
harbor.test/ml-models/fraud-detector:1.0.0-build.123
harbor.test/ml-models/fraud-detector:1.0.0-sha.abc123

# Environment-specific tags
harbor.test/ml-models/fraud-detector:1.0.0-staging
harbor.test/ml-models/fraud-detector:1.0.0-production
```

### Resource Management
```yaml
# Production resource settings
harbor_core_memory_request: "1Gi"
harbor_core_memory_limit: "2Gi"
harbor_registry_memory_request: "1Gi"
harbor_registry_memory_limit: "2Gi"
harbor_database_memory_request: "1Gi"
harbor_database_memory_limit: "2Gi"
```

## Monitoring

Harbor provides metrics endpoints for monitoring:

```bash
# Harbor metrics (if enabled)
curl http://192.168.1.210/api/v2.0/metrics

# Registry storage usage
kubectl exec -n harbor harbor-registry-<pod> -- df -h /storage
```

## Integration Examples

### CI/CD Pipeline
```yaml
# GitLab CI example
build:
  script:
    - docker build -t $IMAGE_TAG .
    - docker login $HARBOR_URL -u $HARBOR_USER -p $HARBOR_PASSWORD
    - docker push $IMAGE_TAG
    - echo "Image pushed to Harbor: $IMAGE_TAG"
```

### Kubernetes Deployment
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ml-app
spec:
  template:
    spec:
      imagePullSecrets:
      - name: harbor-registry-secret
      containers:
      - name: app
        image: harbor.test/ml-models/fraud-detector:v1.0
```

## References

- [Harbor Documentation](https://goharbor.io/docs/)
- [Harbor API Reference](https://goharbor.io/docs/latest/build-customize-contribute/configure-swagger/)
- [Trivy Scanner](https://aquasecurity.github.io/trivy/)

---

**Role Version**: 1.0.0  
**Harbor Version**: 2.x (via Helm chart)  
**Maintained By**: Platform Team