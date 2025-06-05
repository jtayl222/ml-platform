# Seldon Core Role

This role deploys Seldon Core for ML model serving and deployment.

## Features

- **Model Serving**: Deploy ML models as microservices
- **Multi-framework Support**: Scikit-Learn, MLflow, TensorFlow, PyTorch
- **Auto-scaling**: Kubernetes-native scaling (when KEDA enabled)
- **A/B Testing**: Advanced deployment strategies
- **Monitoring**: Prometheus metrics integration

## Components Deployed

- **Seldon Core Operator**: Manages model deployments
- **CRDs**: Custom resources for model deployments
- **RBAC**: Role-based access control
- **Sample Templates**: Ready-to-use model examples

## Configuration

### Required Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `seldon_namespace` | Namespace for Seldon Core | seldon-system |
| `seldon_nodeport` | NodePort for external access | 32000 |

### Optional Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `seldon_usage_metrics` | Enable usage metrics | true |
| `seldon_istio_enabled` | Enable Istio integration | false |
| `seldon_keda_enabled` | Enable auto-scaling | false |

## Usage

```yaml
- name: Deploy Seldon Core
  include_role:
    name: platform/seldon
  tags: [platform, seldon]
```

## Model Deployment Example

```yaml
apiVersion: machinelearning.seldon.io/v1
kind: SeldonDeployment
metadata:
  name: iris-model
spec:
  name: iris
  predictors:
  - graph:
      implementation: SKLEARN_SERVER
      modelUri: gs://seldon-models/sklearn/iris
      name: classifier
    name: default
    replicas: 1
```

## Testing Models

```bash
# Deploy a model
kubectl apply -f iris-model.yaml

# Test the model
curl -X POST http://192.168.1.85:32000/seldon/seldon-system/iris-model/api/v1.0/predictions \
  -H 'Content-Type: application/json' \
  -d '{"data": {"ndarray": [[1, 2, 3, 4]]}}'
```