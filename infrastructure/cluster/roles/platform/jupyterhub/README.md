# JupyterHub Role

This role deploys JupyterHub for collaborative data science and ML development.

## Features

- **Multi-user Environment**: Isolated Jupyter notebooks for each user
- **MLOps Integration**: Pre-configured MLflow and MinIO connectivity
- **Resource Management**: Configurable CPU and memory limits
- **Storage Options**: Dynamic persistent volumes or ephemeral storage
- **Pre-installed Packages**: MLOps stack ready out of the box

## Components Deployed

- **JupyterHub**: Central authentication and user management
- **JupyterLab**: Modern notebook interface
- **User Pods**: Individual user environments
- **MLOps ConfigMap**: Environment configuration

## Configuration

### Required Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `jupyterhub_namespace` | Namespace for JupyterHub | jupyterhub |
| `jupyterhub_nodeport` | NodePort for external access | 30888 |
| `jupyterhub_password` | Demo authentication password | mlops123 |

### Optional Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `jupyterhub_storage_type` | Storage type (none/dynamic) | none |
| `jupyterhub_user_memory_limit` | User pod memory limit | 2Gi |
| `jupyterhub_image_name` | Jupyter notebook image | jupyter/datascience-notebook |

## Usage

```yaml
- name: Deploy JupyterHub
  include_role:
    name: platform/jupyterhub
  tags: [platform, jupyter]
```

## Access

- **URL**: http://CLUSTER_IP:30888
- **Auth**: Any username with password 'mlops123'
- **Interface**: JupyterLab by default

## Pre-installed Packages

- mlflow
- boto3
- scikit-learn
- pandas
- numpy
- matplotlib
- seaborn