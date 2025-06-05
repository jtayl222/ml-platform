# Kubernetes Dashboard Role

This role deploys the Kubernetes Dashboard with admin access and demo-friendly configuration.

## Features

- **Web-based UI**: Complete cluster management interface
- **Admin Access**: Pre-configured admin service account
- **Skip Login**: Demo-friendly authentication bypass
- **NodePort Access**: External access via NodePort service
- **RBAC**: Proper role-based access control
- **Token Support**: Service account token generation

## Components Deployed

- **Kubernetes Dashboard**: Main dashboard application
- **Kong Proxy**: API gateway for dashboard access
- **Admin ServiceAccount**: Full cluster admin access
- **NodePort Service**: External connectivity
- **ClusterRoleBinding**: Admin permissions

## Configuration

### Required Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `dashboard_namespace` | Dashboard namespace | kubernetes-dashboard |
| `dashboard_nodeport` | NodePort for external access | 30444 |

### Optional Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `dashboard_skip_login` | Enable skip login for demo | true |
| `dashboard_admin_account` | Admin service account name | dashboard-admin |
| `dashboard_enable_insecure_login` | Allow insecure login | true |

## Usage

```yaml
- name: Deploy Kubernetes Dashboard
  include_role:
    name: platform/dashboard
  tags: [platform, dashboard]
```

## Access Methods

### 1. NodePort Access (Recommended for demos)
- **URL**: https://CLUSTER_IP:30444
- **Auth**: Skip login enabled (click "Skip" button)

### 2. kubectl proxy
```bash
kubectl proxy --port=8001
# Visit: http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/
```

### 3. Token-based Access
```bash
# Get admin token
kubectl get secret dashboard-admin-token -n kubernetes-dashboard -o jsonpath='{.data.token}' | base64 -d
```

## Security Notes

- **Demo Configuration**: Skip login is enabled for easy access
- **Admin Permissions**: Dashboard has full cluster admin rights
- **Production Use**: Disable skip login and use proper authentication
- **Network Security**: Consider using ingress with TLS termination

## Troubleshooting

### Common Issues

1. **Dashboard not accessible**: Check NodePort service and firewall
2. **Skip login not working**: Verify extraArgs in Helm values
3. **Permission denied**: Check ClusterRoleBinding for admin account

### Debug Commands

```bash
# Check dashboard pods
kubectl get pods -n kubernetes-dashboard

# Check services
kubectl get svc -n kubernetes-dashboard

# Check admin token
kubectl describe secret dashboard-admin-token -n kubernetes-dashboard

# Port forward for debugging
kubectl port-forward -n kubernetes-dashboard svc/kubernetes-dashboard-kong-proxy 8443:443
```