#!/bin/bash
# Fix Harbor certificate trust for K3s containerd
# This script properly configures containerd to trust Harbor's self-signed certificate

set -euo pipefail

# Configuration
HARBOR_NAMESPACE="harbor"
HARBOR_SECRET="harbor-tls"
HARBOR_DOMAIN="harbor.test"
HARBOR_IP="192.168.1.210"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# K3s nodes
K3S_NODES=(
    "nuc8i5behs"    # control-plane
    "nuc10i3fnh"    # worker
    "nuc10i4fnh"    # worker  
    "nuc10i5fnh"    # worker
    "nuc10i7fnh"    # worker
)

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Extract Harbor certificate
extract_certificate() {
    log "Extracting Harbor certificate..."
    
    local cert_file="/tmp/harbor-ca.crt"
    if kubectl get secret "$HARBOR_SECRET" -n "$HARBOR_NAMESPACE" -o jsonpath='{.data.tls\.crt}' | base64 -d > "$cert_file"; then
        log "Certificate extracted successfully"
        echo "$cert_file"
    else
        error "Failed to extract certificate"
        exit 1
    fi
}

# Configure containerd for Harbor on a single node
configure_containerd_on_node() {
    local node="$1"
    local cert_file="$2"
    
    log "Configuring containerd on node: $node"
    
    # Create containerd certs directory
    ssh "$node" "sudo mkdir -p /etc/containerd/certs.d/$HARBOR_DOMAIN"
    
    # Copy certificate
    scp "$cert_file" "$node":/tmp/harbor-ca.crt
    ssh "$node" "sudo mv /tmp/harbor-ca.crt /etc/containerd/certs.d/$HARBOR_DOMAIN/ca.crt"
    ssh "$node" "sudo chmod 644 /etc/containerd/certs.d/$HARBOR_DOMAIN/ca.crt"
    
    # Create hosts.toml for containerd
    ssh "$node" "sudo tee /etc/containerd/certs.d/$HARBOR_DOMAIN/hosts.toml > /dev/null" <<EOF
server = "https://$HARBOR_DOMAIN"

[host."https://$HARBOR_DOMAIN"]
  capabilities = ["pull", "resolve"]
  ca = "/etc/containerd/certs.d/$HARBOR_DOMAIN/ca.crt"
  skip_verify = false
EOF
    
    # Restart K3s to reload containerd configuration
    log "Restarting K3s on $node..."
    ssh "$node" "sudo systemctl restart k3s || sudo systemctl restart k3s-agent"
    
    # Wait for K3s to be ready
    sleep 10
    
    log "Containerd configured on $node ✅"
}

# Test containerd certificate on a node
test_containerd_on_node() {
    local node="$1"
    
    log "Testing containerd certificate on node: $node"
    
    # Test with ctr (containerd CLI)
    if ssh "$node" "sudo ctr --namespace k8s.io image pull harbor.test/library/hello-world:test --plain-http=false" 2>/dev/null; then
        log "Containerd pull test passed on $node ✅"
        return 0
    else
        warn "Containerd pull test failed on $node"
        return 1
    fi
}

# Configure containerd on all nodes
configure_all_nodes() {
    local cert_file="$1"
    
    log "Configuring containerd on all K3s nodes..."
    
    local success_count=0
    local failed_nodes=()
    
    for node in "${K3S_NODES[@]}"; do
        if configure_containerd_on_node "$node" "$cert_file"; then
            ((success_count++))
        else
            failed_nodes+=("$node")
        fi
    done
    
    log "Containerd configuration completed: $success_count/${#K3S_NODES[@]} nodes"
    
    if [[ ${#failed_nodes[@]} -gt 0 ]]; then
        error "Failed to configure containerd on: ${failed_nodes[*]}"
        return 1
    fi
    
    return 0
}

# Wait for K3s cluster to be ready
wait_for_cluster() {
    log "Waiting for K3s cluster to be ready..."
    
    local timeout=300
    local elapsed=0
    
    while [[ $elapsed -lt $timeout ]]; do
        if kubectl get nodes --no-headers 2>/dev/null | grep -q "Ready"; then
            log "K3s cluster is ready ✅"
            return 0
        fi
        
        sleep 5
        elapsed=$((elapsed + 5))
        echo -n "."
    done
    
    error "K3s cluster not ready after ${timeout}s"
    return 1
}

# Test image pull from Kubernetes
test_kubernetes_image_pull() {
    log "Testing Kubernetes image pull from Harbor..."
    
    # Create a test pod that pulls from Harbor
    kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: harbor-test-pod
  namespace: default
spec:
  containers:
  - name: test
    image: harbor.test/library/hello-world:test
    imagePullPolicy: Always
    command: ["/bin/sh", "-c", "echo 'Harbor test successful' && sleep 30"]
  restartPolicy: Never
EOF
    
    # Wait for pod to be ready
    local timeout=120
    local elapsed=0
    
    while [[ $elapsed -lt $timeout ]]; do
        local status=$(kubectl get pod harbor-test-pod -o jsonpath='{.status.phase}' 2>/dev/null || echo "Pending")
        
        if [[ "$status" == "Running" ]] || [[ "$status" == "Succeeded" ]]; then
            log "Harbor image pull test successful ✅"
            kubectl delete pod harbor-test-pod --ignore-not-found
            return 0
        elif [[ "$status" == "Failed" ]]; then
            error "Harbor image pull test failed"
            kubectl describe pod harbor-test-pod
            kubectl delete pod harbor-test-pod --ignore-not-found
            return 1
        fi
        
        sleep 5
        elapsed=$((elapsed + 5))
        echo -n "."
    done
    
    error "Harbor image pull test timed out"
    kubectl describe pod harbor-test-pod
    kubectl delete pod harbor-test-pod --ignore-not-found
    return 1
}

# Main function
main() {
    log "Starting K3s Harbor certificate configuration..."
    
    # Extract certificate
    local cert_file
    cert_file=$(extract_certificate)
    
    # Configure all nodes
    if configure_all_nodes "$cert_file"; then
        log "Containerd configuration successful on all nodes"
    else
        error "Containerd configuration failed on some nodes"
        exit 1
    fi
    
    # Wait for cluster to be ready
    wait_for_cluster
    
    # Test Kubernetes image pull
    if test_kubernetes_image_pull; then
        log "Kubernetes Harbor integration test successful ✅"
    else
        error "Kubernetes Harbor integration test failed"
        exit 1
    fi
    
    # Cleanup
    rm -f "$cert_file"
    
    log "K3s Harbor certificate configuration completed successfully! 🚀"
    log "Kubernetes pods can now pull images from Harbor: harbor.test/library/*"
}

# Run main function
main "$@"