# Cilium CNI Role

Ansible role for deploying and managing Cilium eBPF-based Container Network Interface (CNI) in K3s clusters.

## Overview

Cilium provides **high-performance networking and security** using eBPF technology. This role:
- **Replaces K3s Flannel** - Disables built-in Flannel and deploys Cilium
- **eBPF Dataplane** - Kernel-native networking for maximum performance
- **Network Policies** - Layer 3/4/7 security policies for microservices
- **Service Mesh Ready** - Native integration with Istio and service mesh
- **Observability** - Hubble for network visibility and troubleshooting

## Architecture

```
🌐 Cilium CNI Architecture
├── 🧠 eBPF Dataplane (Kernel)
│   ├── XDP programs (packet processing)
│   ├── TC programs (traffic control)
│   ├── Socket operations (L7 policies)
│   └── Kprobe tracing (observability)
├── 🔗 Cilium Agent (DaemonSet)
│   ├── Pod networking and IPAM
│   ├── Service load balancing
│   ├── Network policy enforcement
│   └── Encryption (WireGuard/IPSec)
├── 🎛️ Cilium Operator (Deployment)
│   ├── CRD management
│   ├── Cluster-wide operations
│   ├── IP address management
│   └── BGP routing (optional)
├── 👁️ Hubble Observability
│   ├── Network flow monitoring
│   ├── Security event tracking
│   ├── Service dependency mapping
│   └── Web UI for visualization
└── 🔒 Network Policies
    ├── Layer 3/4 traditional policies
    ├── Layer 7 application policies
    ├── DNS-based policies
    └── Identity-based security
```

## Features

### ✅ Core Networking
- **eBPF Dataplane** - Kernel-native networking with minimal overhead
- **VXLAN Tunneling** - Overlay networking for pod-to-pod communication
- **Direct Routing** - Native routing when network topology allows
- **IPv4/IPv6 Dual Stack** - Support for both IP versions
- **IPAM** - Advanced IP address management with cluster pools

### ✅ Service Mesh Integration
- **Kube-proxy Replacement** - eBPF-based service load balancing
- **Service Mesh Ready** - Native Istio and Envoy integration
- **L7 Load Balancing** - Application-aware traffic distribution
- **Circuit Breaking** - Automatic failure detection and recovery

### ✅ Security
- **Network Policies** - Kubernetes NetworkPolicy enforcement
- **Cilium Network Policies** - Extended L3/4/7 policies
- **Identity-based Security** - Cryptographic pod identity
- **Encryption** - WireGuard or IPSec transparent encryption
- **Runtime Security** - Process and file system monitoring

### ✅ Observability
- **Hubble** - Network flow visibility and monitoring
- **Service Maps** - Automatic service dependency discovery
- **Golden Signals** - Latency, traffic, errors, saturation metrics
- **Grafana Integration** - Rich dashboards and alerting

## Requirements

### System Requirements
- **Kernel**: Linux 4.9+ with eBPF support
- **K3s**: Version 1.19+ with Flannel disabled
- **Memory**: 512Mi+ per node for Cilium agent
- **CPU**: 100m+ per node for basic operation

### Dependencies
- Kubernetes cluster with disabled CNI (`--flannel-backend=none`)
- Helm 3.0+ for chart deployment
- `kubeconfig_path` variable pointing to cluster config
- Ansible collections:
  - `kubernetes.core`

### Kernel Feature Verification
```bash
# Check eBPF support
ls /sys/fs/bpf/

# Verify required kernel modules
modprobe ip_tables
modprobe ip6_tables
modprobe iptable_nat
modprobe ip6table_nat
```

## Role Variables

### Required Variables
```yaml
kubeconfig_path: /path/to/kubeconfig  # Path to cluster kubeconfig
```

### Core Configuration
```yaml
# Deployment Configuration
cilium_enabled: true                  # Enable Cilium deployment
cilium_state: present                 # present|absent
cilium_version: "1.16.5"              # Cilium version
cilium_namespace: kube-system         # Installation namespace

# Network Configuration
cilium_cluster_pool_ipv4_cidr: "10.42.0.0/16"    # Pod CIDR (matches K3s)
cilium_k8s_service_host: "192.168.1.85"          # API server IP
cilium_k8s_service_port: "6443"                  # API server port
```

### Advanced Configuration
```yaml
# Dataplane Configuration
cilium_kube_proxy_replacement: true   # Replace kube-proxy with eBPF
cilium_routing_mode: "tunnel"         # tunnel|native
cilium_tunnel_protocol: "vxlan"       # vxlan|geneve
cilium_ipam_mode: "cluster-pool"      # cluster-pool|kubernetes

# Protocol Support
cilium_enable_ipv4: true              # IPv4 support
cilium_enable_ipv6: false             # IPv6 support

# Security Features
cilium_enable_network_policy: true    # Kubernetes NetworkPolicy
cilium_enable_cilium_network_policy: true  # Extended Cilium policies
cilium_enable_encryption: false      # Transparent encryption
cilium_enable_wireguard: false       # WireGuard encryption

# Observability
cilium_enable_hubble: true            # Enable Hubble observability
cilium_hubble_relay_enabled: true    # Hubble relay for aggregation
cilium_hubble_ui_enabled: true       # Web UI for visualization

# Advanced Features
cilium_enable_bgp: false              # BGP routing protocol
```

## Deployment

### 1. Basic Cilium Deployment
```bash
# Deploy Cilium CNI (default configuration)
ansible-playbook -i inventory/production/hosts infrastructure/cluster/site.yml --tags="cilium"
```

### 2. K3s with Cilium
```bash
# Deploy K3s cluster with Cilium CNI
ansible-playbook site.yml --tags="k3s,cilium"

# Deploy only CNI (cluster must exist)
ansible-playbook site.yml --tags="cni,networking"
```

### 3. Advanced Configuration
```bash
# Deploy with WireGuard encryption
ansible-playbook site.yml --tags="cilium" -e "cilium_enable_encryption=true" -e "cilium_enable_wireguard=true"

# Deploy with BGP routing
ansible-playbook site.yml --tags="cilium" -e "cilium_enable_bgp=true" -e "cilium_routing_mode=native"

# Deploy with IPv6 support
ansible-playbook site.yml --tags="cilium" -e "cilium_enable_ipv6=true"
```

### 4. Observability Focus
```bash
# Deploy with full Hubble observability
ansible-playbook site.yml --tags="cilium" -e "cilium_hubble_ui_enabled=true"
```

## Available Tags

- `cilium` - All Cilium CNI tasks
- `cni` - Container networking interface tasks
- `networking` - Network configuration
- `install` - Cilium installation tasks
- `observability` - Hubble and monitoring
- `security` - Network policy and encryption
- `bgp` - BGP routing configuration

## Network Configuration

### Pod and Service CIDRs
```yaml
# Default Network Configuration (matches K3s)
Pod CIDR:     10.42.0.0/16    # Cilium cluster pool
Service CIDR: 10.43.0.0/16    # K3s service range
Node CIDR:    192.168.1.0/24  # Physical network
```

### Port Requirements
```bash
# Cilium Core Ports
4240/tcp     # Cilium health checks
4244/tcp     # Hubble relay server
4245/tcp     # Hubble UI
8080/tcp     # Cilium agent health endpoint
9090/tcp     # Cilium agent prometheus metrics
9091/tcp     # Cilium operator prometheus metrics
9962/tcp     # Cilium operator metrics
9963/tcp     # Cilium proxy metrics

# Overlay Networking
8472/udp     # VXLAN tunnel protocol
4789/udp     # VXLAN (alternative)

# Encryption (optional)
51871/udp    # WireGuard encryption

# BGP (optional)
179/tcp      # BGP routing protocol
```

### Firewall Configuration
```bash
# Allow Cilium traffic in UFW
sudo ufw allow 4240/tcp comment 'Cilium health'
sudo ufw allow 4244/tcp comment 'Hubble relay'
sudo ufw allow 8472/udp comment 'Cilium VXLAN'
sudo ufw allow from 10.42.0.0/16 comment 'Pod network'
sudo ufw allow from 10.43.0.0/16 comment 'Service network'
```

## Integration

### K3s Integration
```yaml
# K3s must be configured without Flannel
INSTALL_K3S_EXEC: "--flannel-backend=none --disable-network-policy"

# Cilium replaces these K3s components:
# - Flannel CNI
# - kube-proxy (when cilium_kube_proxy_replacement: true)
# - CoreDNS network policies
```

### Seldon Core v2 Integration
```yaml
# Cilium provides required network policies for Seldon
spec:
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: seldon-system
    ports:
    - protocol: TCP
      port: 9000
```

### Istio Service Mesh
```yaml
# Cilium enhances Istio with eBPF acceleration
# Socket-level load balancing
# Reduced latency with kernel bypass
# Enhanced observability correlation
```

### MetalLB Integration
```yaml
# Cilium works seamlessly with MetalLB
# BGP mode: Cilium BGP + MetalLB BGP = efficient routing
# L2 mode: MetalLB handles external IPs, Cilium handles pod networking
```

## Observability

### Hubble UI Access
```bash
# Port-forward Hubble UI
kubectl port-forward -n kube-system service/hubble-ui 12000:80

# Access UI
open http://localhost:12000
```

### Hubble CLI
```bash
# Install Hubble CLI
HUBBLE_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/hubble/master/stable.txt)
curl -L --remote-name-all https://github.com/cilium/hubble/releases/download/$HUBBLE_VERSION/hubble-linux-amd64.tar.gz
tar xzvf hubble-linux-amd64.tar.gz
sudo install hubble /usr/local/bin

# Use Hubble CLI
hubble observe                           # Live flow monitoring
hubble observe --namespace default       # Namespace-specific flows
hubble observe --pod cilium-test         # Pod-specific flows
hubble observe --protocol tcp           # Protocol filtering
```

### Cilium CLI
```bash
# Install Cilium CLI
CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/master/stable.txt)
curl -L --remote-name-all https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-amd64.tar.gz
tar xzvf cilium-linux-amd64.tar.gz
sudo install cilium /usr/local/bin

# Cilium status and diagnostics
cilium status                            # Overall cluster status
cilium connectivity test                 # Comprehensive connectivity test
cilium policy get                        # List network policies
cilium endpoint list                     # List all endpoints
```

## Network Policies

### Basic Kubernetes NetworkPolicy
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all
  namespace: default
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
```

### Cilium NetworkPolicy (L7)
```yaml
apiVersion: "cilium.io/v2"
kind: CiliumNetworkPolicy
metadata:
  name: http-only
  namespace: default
spec:
  endpointSelector:
    matchLabels:
      app: web
  ingress:
  - fromEndpoints:
    - matchLabels:
        app: frontend
    toPorts:
    - ports:
      - port: "80"
        protocol: TCP
      rules:
        http:
        - method: GET
          path: "/api/.*"
```

### DNS-based Policies
```yaml
apiVersion: "cilium.io/v2"
kind: CiliumNetworkPolicy
metadata:
  name: dns-policy
spec:
  endpointSelector:
    matchLabels:
      app: backend
  egress:
  - toFQDNs:
    - matchName: "api.example.com"
  - toPorts:
    - ports:
      - port: "53"
        protocol: UDP
```

## Troubleshooting

### Common Issues

#### 1. eBPF Not Supported
```bash
# Check kernel version
uname -r

# Verify eBPF filesystem
mount | grep bpf
ls /sys/fs/bpf/

# Check required modules
lsmod | grep -E "ip_tables|iptable_nat"
```

#### 2. Cilium Pods Not Starting
```bash
# Check Cilium agent status
kubectl get pods -n kube-system | grep cilium
kubectl logs -n kube-system daemonset/cilium

# Check Cilium operator
kubectl logs -n kube-system deployment/cilium-operator

# Verify node readiness
kubectl get nodes -o wide
cilium status --wait
```

#### 3. Network Connectivity Issues
```bash
# Test pod-to-pod connectivity
kubectl run test-pod --image=nicolaka/netshoot --rm -it -- /bin/bash
# Inside pod: ping <other-pod-ip>

# Check Cilium endpoints
cilium endpoint list
cilium endpoint get <endpoint-id>

# Test DNS resolution
nslookup kubernetes.default.svc.cluster.local
```

#### 4. Network Policy Issues
```bash
# Check policy status
cilium policy get
kubectl get cnp,netpol --all-namespaces

# Debug policy enforcement
cilium policy trace <src-endpoint> <dst-endpoint>
hubble observe --verdict=denied
```

#### 5. Hubble Issues
```bash
# Check Hubble relay
kubectl get pods -n kube-system | grep hubble
kubectl logs -n kube-system deployment/hubble-relay

# Test Hubble connectivity
hubble status
hubble observe --number 10
```

### Health Checks
```bash
# Comprehensive Cilium health check
cilium status --all-health

# Connectivity test suite
cilium connectivity test

# Node connectivity
cilium node list
cilium monitor

# Service connectivity
kubectl get svc --all-namespaces
cilium service list
```

### Performance Monitoring
```bash
# Monitor eBPF program performance
cilium bpf lb list
cilium bpf nat list
cilium bpf policy get

# Check resource usage
kubectl top pods -n kube-system | grep cilium
kubectl describe node | grep -A 5 "cilium"
```

## Security Best Practices

### Network Isolation
```yaml
# Implement zero-trust networking
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: production
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
```

### Encryption
```yaml
# Enable WireGuard encryption
cilium_enable_encryption: true
cilium_enable_wireguard: true

# Alternative: IPSec encryption
cilium_enable_encryption: true
cilium_enable_wireguard: false
```

### Identity Management
```bash
# Monitor security identities
cilium identity list
cilium identity get <identity-id>

# Track security events
hubble observe --verdict=denied --follow
```

## Performance Tuning

### eBPF Optimization
```yaml
# Optimize for performance
cilium_enable_bpf_masquerade: true
cilium_enable_host_routing: true
cilium_tunnel_protocol: "disabled"  # Use native routing when possible
```

### Resource Allocation
```yaml
# Cilium agent resources (per node)
resources:
  requests:
    cpu: 100m
    memory: 512Mi
  limits:
    cpu: 4000m
    memory: 4Gi

# Cilium operator resources
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 1000m
    memory: 1Gi
```

### Monitoring
```bash
# Prometheus metrics
kubectl port-forward -n kube-system svc/cilium-agent 9090:9090
curl http://localhost:9090/metrics

# Grafana dashboards
# Import Cilium official dashboards from grafana.com
```

## Migration

### From Flannel to Cilium
```bash
# 1. Drain nodes (optional, for zero-downtime)
kubectl drain <node-name> --ignore-daemonsets

# 2. Update K3s configuration
# Remove Flannel: --flannel-backend=none

# 3. Install Cilium
ansible-playbook site.yml --tags="cilium"

# 4. Uncordon nodes
kubectl uncordon <node-name>
```

### From Calico to Cilium
```bash
# 1. Remove Calico
kubectl delete -f calico.yaml

# 2. Clean up
rm -rf /etc/cni/net.d/*
rm -rf /opt/cni/bin/calico*

# 3. Install Cilium
ansible-playbook site.yml --tags="cilium"
```

## Development

### Testing
```bash
# Run Cilium connectivity test
cilium connectivity test --all-flows

# Custom test scenarios
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: network-test
  labels:
    app: test
spec:
  containers:
  - name: test
    image: nicolaka/netshoot
    command: ["/bin/sleep", "3600"]
EOF
```

### Custom Policies
```bash
# Test policy impact
cilium policy trace --src-k8s-pod default:test-pod --dst-k8s-pod default:target-pod --dport 80

# Validate policy syntax
cilium policy validate policy.yaml
```

## Links

- [Cilium Documentation](https://docs.cilium.io/)
- [eBPF Introduction](https://ebpf.io/)
- [Hubble Observability](https://github.com/cilium/hubble)
- [Cilium Helm Charts](https://github.com/cilium/cilium/tree/master/install/kubernetes/cilium)
- [Network Policy Recipes](https://github.com/ahmetb/kubernetes-network-policy-recipes)

---

**Part of the K3s Homelab MLOps Platform** | [Main Documentation](../../README.md)