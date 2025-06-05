# Prometheus Stack Role

This role deploys the complete Prometheus monitoring stack using the `kube-prometheus-stack` Helm chart.

## Components Deployed

- **Prometheus Server**: Metrics collection and storage
- **Grafana**: Visualization and dashboarding  
- **AlertManager**: Alert handling and routing
- **Node Exporter**: Node-level metrics
- **Kube-State-Metrics**: Kubernetes cluster metrics

## Configuration

### Key Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `grafana_nodeport` | 30300 | Grafana web UI port |
| `prometheus_nodeport` | 30090 | Prometheus web UI port |
| `grafana_admin_password` | admin123 | Grafana admin password |
| `prometheus_storage_size` | 10Gi | Prometheus data retention size |

### Resource Configuration

Configurable resource requests and limits for:
- Prometheus server
- Grafana
- AlertManager

## Usage

```yaml
- name: Deploy Monitoring Stack
  include_role:
    name: monitoring/prometheus_stack
  tags: [monitoring]
```

## Access URLs

- **Grafana**: http://CLUSTER_IP:30300 (admin/admin123)
- **Prometheus**: http://CLUSTER_IP:30090
- **AlertManager**: http://CLUSTER_IP:30093

## Enterprise Features

- Persistent storage for metrics
- Resource limits and requests
- Service monitoring for MLOps components
- Production-ready retention policies