# Argo Workflows Role

This role deploys Argo Workflows for workflow orchestration and MLOps pipelines.

## Features

- **Workflow Orchestration**: DAG-based workflow execution
- **MLOps Integration**: Pre-configured for MLflow and MinIO
- **Resource Management**: Configurable CPU and memory limits
- **Security**: RBAC and authentication configured
- **Sample Templates**: Ready-to-use MLOps workflow templates
- **Auto-cleanup**: TTL strategy for workflow cleanup

## Components Deployed

- **Argo Workflows Server**: Web UI and API server
- **Argo Workflows Controller**: Workflow execution engine
- **RBAC**: Service accounts and role bindings
- **Sample Templates**: MLOps workflow templates

## Configuration

### Required Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `argowf_namespace` | Namespace for Argo Workflows | argowf |
| `argowf_service_nodeport` | NodePort for web UI | 32746 |

### Optional Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `argowf_memory_request` | Memory request | 256Mi |
| `argowf_memory_limit` | Memory limit | 512Mi |
| `argowf_workflow_namespaces` | Allowed workflow namespaces | [argowf, default] |

## Usage

```yaml
- name: Deploy Argo Workflows
  include_role:
    name: platform/argo_workflows
  tags: [platform, workflows]
```

## Access URLs

- **Web UI**: http://CLUSTER_IP:32746
- **CLI**: `argo list -n argowf`

## Sample Workflow

The role creates a sample MLOps workflow template with:
- Data preprocessing step
- Model training step
- Model evaluation step
- MinIO and MLflow integration

## Quick Commands

```bash
# List workflows
argo list -n argowf

# Submit sample workflow
argo submit -n argowf --from workflowtemplate/mlops-workflow-template

# Watch workflow progress
argo get -n argowf <workflow-name>

# Get workflow logs
argo logs -n argowf <workflow-name>
```