# LoadBalancer IP Stability Guide

## Problem Statement

MetalLB dynamically assigns IPs from the configured pool (192.168.1.200-250) to LoadBalancer services. Without explicit IP pinning, services can grab different IPs on each deployment, causing:

- **Broken bookmarks and scripts** that reference specific IPs
- **DNS mismatches** if /etc/hosts entries become stale  
- **Integration failures** when hardcoded endpoints change
- **Monitoring disruption** as dashboards lose their targets

## Root Cause Analysis

The IP instability occurred because:

1. **Seldon Core v2 Helm charts** create LoadBalancer services without IP annotations
2. **Service creation order** varies between deployments
3. **First-come-first-served allocation** - services grab any available IP from the pool
4. **Namespace proliferation** - Multiple Seldon deployments across namespaces compete for IPs

Example conflict:
- MLflow was configured for `192.168.1.201`
- Seldon-scheduler deployed first and grabbed `192.168.1.201`  
- MLflow got auto-assigned `192.168.1.215` as fallback

## Solution: Three-Layer IP Management

### Layer 1: Central IP Allocation Registry

Created `/inventory/production/group_vars/metallb_ip_allocations.yml`:

```yaml
# Core Infrastructure (200-209)
minio_loadbalancer_ip: "192.168.1.200"
mlflow_loadbalancer_ip: "192.168.1.215"  # STABLE
argocd_loadbalancer_ip: "192.168.1.204"
grafana_loadbalancer_ip: "192.168.1.207"

# Application Seldon (220-239)  
financial_inference_scheduler_ip: "192.168.1.220"
financial_inference_mesh_ip: "192.168.1.221"
```

### Layer 2: Ansible Service Definitions

Updated all Ansible-managed services to use variables:

```yaml
annotations:
  metallb.universe.tf/loadBalancer-ips: "{{ mlflow_loadbalancer_ip }}"
```

### Layer 3: Post-Deployment Stabilization

For Helm-deployed services (like Seldon), use the stabilization script:

```bash
./scripts/stabilize-loadbalancer-ips.sh
```

## Stable IP Assignments

| Service | Namespace | Stable IP | Port | URL |
|---------|-----------|-----------|------|-----|
| **MLflow** | mlflow | 192.168.1.215 | 5000 | http://192.168.1.215:5000 |
| MinIO | minio | 192.168.1.200 | 9000 | http://192.168.1.200:9000 |
| Seldon Scheduler | seldon-system | 192.168.1.201 | 9002 | http://192.168.1.201:9002 |
| Seldon Mesh | seldon-system | 192.168.1.202 | 80 | http://192.168.1.202 |
| ArgoCD | argocd | 192.168.1.204 | 80 | http://192.168.1.204 |
| Argo Workflows | argowf | 192.168.1.205 | 2746 | http://192.168.1.205 |
| JupyterHub | jupyterhub | 192.168.1.206 | 80 | http://192.168.1.206 |
| Grafana | monitoring | 192.168.1.207 | 3000 | http://192.168.1.207:3000 |
| Dashboard | kubernetes-dashboard | 192.168.1.208 | 443 | https://192.168.1.208 |
| Prometheus PushGW | monitoring | 192.168.1.209 | 9091 | http://192.168.1.209:9091 |

## Implementation Steps

### 1. Initial Deployment

```bash
# Deploy platform with MetalLB
ansible-playbook -i inventory/production/hosts \
  infrastructure/cluster/site.yml \
  -e metallb_state=present
```

### 2. Stabilize IPs

```bash
# Run stabilization script
./scripts/stabilize-loadbalancer-ips.sh

# Verify assignments
kubectl get svc -A | grep LoadBalancer
```

### 3. Update DNS

Add to `/etc/hosts`:

```bash
192.168.1.215   mlflow.test              # NEW stable IP
192.168.1.200   minio.test
192.168.1.207   grafana.test
```

### 4. Update Integrations

```python
# Update MLflow tracking URI
mlflow.set_tracking_uri("http://192.168.1.215:5000")
```

## Maintenance Procedures

### After New Service Deployments

Always run the stabilization script after deploying new services:

```bash
# Deploy new service
kubectl apply -f new-service.yaml

# Stabilize all IPs
./scripts/stabilize-loadbalancer-ips.sh
```

### Adding New Services

1. Reserve IP in `metallb_ip_allocations.yml`
2. Update Ansible role to use variable
3. Add to stabilization script
4. Document in this guide

### Troubleshooting IP Conflicts

```bash
# Check which service has an IP
kubectl get svc -A -o wide | grep "192.168.1.201"

# Force IP reassignment
kubectl annotate svc mlflow -n mlflow \
  metallb.universe.tf/loadBalancer-ips=192.168.1.215 \
  --overwrite

# Restart MetalLB controller if needed
kubectl rollout restart deployment/controller -n metallb-system
```

## Best Practices

1. **Never hardcode IPs** - Always use variables from `metallb_ip_allocations.yml`
2. **Document all IPs** - Keep this guide updated with any changes
3. **Run stabilization** - After every deployment or cluster restart
4. **Monitor assignments** - Set up alerts for IP changes
5. **Use DNS names** - Prefer hostnames over IPs in application code

## Migration Checklist

- [x] Create IP allocation registry
- [x] Update MLflow to use stable IP (192.168.1.215)
- [x] Create stabilization script
- [x] Document all stable assignments
- [ ] Update all documentation references
- [ ] Update monitoring dashboards
- [ ] Notify team of new MLflow endpoint
- [ ] Add IP monitoring alerts

## FAQ

**Q: Why did MLflow move from 192.168.1.201 to 192.168.1.215?**
A: Seldon Core services deployed without IP pinning and grabbed 201 first. We've now assigned MLflow a stable IP at 215.

**Q: Will IPs change again?**
A: No, with the stabilization script and IP registry in place, IPs will remain stable.

**Q: What if I need to change an IP?**
A: Update `metallb_ip_allocations.yml`, modify the stabilization script, and run it to apply changes.

**Q: Can services share IPs?**
A: Yes, using MetalLB's shared IP feature, but we avoid this for clarity.

## Summary

The LoadBalancer IP instability issue has been resolved through:

1. **Central IP registry** for all service assignments
2. **Ansible variables** for service definitions  
3. **Stabilization script** for post-deployment fixes
4. **MLflow stable at 192.168.1.215:5000**

This ensures platform stability and prevents future IP reassignment issues.