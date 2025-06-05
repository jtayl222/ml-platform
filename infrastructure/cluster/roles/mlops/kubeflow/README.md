# Kubeflow Pipelines Role

Deploys Kubeflow Pipelines using upstream Kustomize manifests.

## Features

- Platform-agnostic Kubeflow Pipelines deployment
- Automatic TLS certificate generation for webhooks
- NodePort service for UI access
- Graceful handling of deployment issues
- Pod restart and recovery mechanisms

## Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `kubeflow_namespace` | `kubeflow` | Kubernetes namespace |
| `kubeflow_ui_nodeport` | `31234` | NodePort for UI access |
| `kubeflow_wait_timeout` | `90` | Seconds to wait for stabilization |

## Usage

```yaml
- name: Deploy Kubeflow Pipelines
  include_role:
    name: kubeflow
  tags: [kubeflow, pipelines]
```

## Troubleshooting

Common issues and solutions:

1. **TLS Certificate Errors**: Role automatically generates self-signed certificates
2. **Pod Startup Issues**: Role includes pod restart logic
3. **Service Account Missing**: Role creates required service accounts

## Access

- UI: `http://192.168.1.85:31234`
- No authentication required (demo configuration)

## Dependencies

- kubectl with cluster access
- OpenSSL for certificate generation