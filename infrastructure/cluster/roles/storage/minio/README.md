# MinIO Storage Role

This role deploys MinIO as S3-compatible object storage for the MLOps platform.

## Features

- **S3-compatible API**: Full AWS S3 API compatibility
- **MLOps Integration**: Pre-configured buckets for MLflow, Argo, and Kubeflow
- **Persistent Storage**: NFS-backed persistent volumes
- **NodePort Access**: External access via NodePort services
- **Resource Management**: Configurable CPU and memory limits

## Configuration

### Required Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `minio_access_key` | MinIO root username | minioadmin |
| `minio_secret_key` | MinIO root password | minioadmin123 |

### Optional Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `minio_storage_size` | Persistent volume size | 20Gi |
| `minio_nodeport` | API NodePort | 30900 |
| `minio_console_nodeport` | Console NodePort | 30901 |

## Usage

```yaml
- name: Deploy MinIO Storage
  include_role:
    name: storage/minio
  tags: [storage]
```

## Access URLs

- **API**: http://CLUSTER_IP:30900
- **Console**: http://CLUSTER_IP:30901

## Pre-created Buckets

- `mlflow-artifacts`: MLflow model artifacts
- `argo-artifacts`: Argo Workflows artifacts  
- `kubeflow-artifacts`: Kubeflow pipeline artifacts