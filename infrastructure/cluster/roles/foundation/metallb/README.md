# MetalLB Load Balancer Role

This Ansible role installs and configures MetalLB, a load balancer implementation for bare metal Kubernetes clusters.

## Overview

MetalLB provides a network load balancer implementation for Kubernetes clusters that do not run on a cloud provider. It allows you to use LoadBalancer services in your homelab or on-premises Kubernetes environment.

## Features

- **Layer 2 (ARP) mode**: Speaker nodes take ownership of service IPs
- **Layer 3 (BGP) mode**: Integrates with BGP routers (not configured by default)
- **IP address pool management**: Automatic IP allocation from configured ranges
- **High availability**: Multiple speaker nodes for redundancy
- **Kubernetes-native**: Uses CRDs for configuration

## Configuration

### Required Variables

Configure these variables in your inventory file:

```yaml
# MetalLB IP Address Pool
metallb_ip_range: "192.168.1.200-192.168.1.250"

# MetalLB Version
metallb_version: "v0.14.8"

# MetalLB Namespace
metallb_namespace: "metallb-system"
```

### Optional Variables

```yaml
# IP Pool Configuration
metallb_ip_pool_name: "homelab-pool"
metallb_advertisement_name: "homelab-l2-advertisement"

# Resource Limits
metallb_controller_resources:
  requests:
    cpu: "100m"
    memory: "100Mi"
  limits:
    cpu: "200m"
    memory: "200Mi"

metallb_speaker_resources:
  requests:
    cpu: "100m"
    memory: "100Mi"
  limits:
    cpu: "200m"
    memory: "200Mi"
```

## Usage

### Deploy MetalLB

```bash
# Deploy MetalLB as part of infrastructure
ansible-playbook -i inventory/production/hosts infrastructure/cluster/site.yml --tags metallb

# Deploy only MetalLB
ansible-playbook -i inventory/production/hosts infrastructure/cluster/site.yml --tags metallb --skip-tags all
```

### Remove MetalLB

```bash
# Remove MetalLB
ansible-playbook -i inventory/production/hosts infrastructure/cluster/site.yml --tags metallb -e metallb_state=absent
```

### Verify Installation

```bash
# Check MetalLB pods
kubectl get pods -n metallb-system

# Check IP address pool
kubectl get ipaddresspool -n metallb-system

# Check L2 advertisement
kubectl get l2advertisement -n metallb-system
```

## Using LoadBalancer Services

Once MetalLB is installed, you can create LoadBalancer services:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-service
spec:
  type: LoadBalancer
  ports:
    - port: 80
      targetPort: 8080
  selector:
    app: my-app
```

MetalLB will automatically assign an IP from the configured pool.

## IP Address Planning

### Default Configuration
- **IP Range**: `192.168.1.200-192.168.1.250`
- **Available IPs**: 51 addresses
- **Network**: Assumes 192.168.1.0/24 home network

### Customization
Adjust the IP range based on your network:

```yaml
# For different network
metallb_ip_range: "10.0.0.200-10.0.0.250"

# Multiple ranges
metallb_ip_range: "192.168.1.200-192.168.1.210,192.168.1.220-192.168.1.230"
```

## Troubleshooting

### Common Issues

1. **IP conflicts**: Ensure IP range doesn't conflict with DHCP
2. **Network connectivity**: Verify L2 connectivity between nodes
3. **Firewall rules**: Check that ARP traffic is allowed

### Debug Commands

```bash
# Check MetalLB logs
kubectl logs -n metallb-system -l app=metallb

# Check speaker logs specifically
kubectl logs -n metallb-system -l component=speaker

# Check controller logs
kubectl logs -n metallb-system -l component=controller
```

## Security Considerations

- IP address pool should be within your network's trusted range
- Consider network segmentation for production deployments
- Monitor IP allocation and usage
- Use appropriate resource limits for production

## Dependencies

- Kubernetes cluster (K3s supported)
- Layer 2 network connectivity between nodes
- Available IP address range not used by DHCP

## Tags

- `metallb`: All MetalLB tasks
- `networking`: Network-related tasks
- `load-balancer`: Load balancer specific tasks
- `metallb-install`: Installation tasks only
- `metallb-config`: Configuration tasks only