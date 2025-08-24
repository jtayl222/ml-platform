#!/bin/bash

# kubeadm_startup.sh
# Startup script for kubeadm-based Kubernetes cluster
# Handles proper node startup sequence and cluster health verification

set -euo pipefail

# Configuration
CONTROL_PLANE_NODES=("192.168.1.85")
WORKER_NODES=("192.168.1.103" "192.168.1.104" "192.168.1.105" "192.168.1.107")
STARTUP_TIMEOUT=300
HEALTH_CHECK_RETRIES=10
HEALTH_CHECK_INTERVAL=30

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

info() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
}

# Check if node is accessible via SSH
check_node_accessibility() {
    local node=$1
    local retries=5
    
    info "Checking accessibility of node: $node"
    
    for ((i=1; i<=retries; i++)); do
        if ssh -o ConnectTimeout=10 -o BatchMode=yes "$node" "echo 'Node accessible'" &>/dev/null; then
            log "Node $node is accessible"
            return 0
        else
            warn "Attempt $i/$retries: Node $node not accessible, waiting..."
            sleep 10
        fi
    done
    
    error "Node $node is not accessible after $retries attempts"
    return 1
}

# Start services on a node
start_node_services() {
    local node=$1
    local node_type=$2
    
    log "Starting services on $node_type node: $node"
    
    # Start container runtime
    ssh "$node" "sudo systemctl start containerd" || {
        error "Failed to start containerd on $node"
        return 1
    }
    
    # Start kubelet
    ssh "$node" "sudo systemctl start kubelet" || {
        error "Failed to start kubelet on $node"
        return 1
    }
    
    # Enable services to start on boot
    ssh "$node" "sudo systemctl enable containerd kubelet" || warn "Failed to enable services on $node"
    
    log "Services started successfully on $node"
}

# Wait for node to become ready
wait_for_node_ready() {
    local node=$1
    local timeout=$2
    local elapsed=0
    
    info "Waiting for node $node to become Ready..."
    
    while [ $elapsed -lt $timeout ]; do
        if kubectl get node "$node" 2>/dev/null | grep -q "Ready"; then
            log "Node $node is Ready"
            return 0
        fi
        
        info "Node $node not ready yet, waiting... (${elapsed}s/${timeout}s)"
        sleep 15
        elapsed=$((elapsed + 15))
    done
    
    error "Node $node did not become Ready within ${timeout}s"
    return 1
}

# Uncordon node (remove drain)
uncordon_node() {
    local node=$1
    
    log "Uncordoning node: $node"
    kubectl uncordon "$node" || {
        warn "Failed to uncordon $node or node was not cordoned"
    }
}

# Start control plane nodes
start_control_plane_nodes() {
    log "Starting control plane nodes..."
    
    for node in "${CONTROL_PLANE_NODES[@]}"; do
        if ! check_node_accessibility "$node"; then
            error "Cannot access control plane node $node. Please ensure it's powered on."
            exit 1
        fi
        
        start_node_services "$node" "control plane"
        
        # Wait for control plane to be ready
        wait_for_node_ready "$node" $STARTUP_TIMEOUT
        uncordon_node "$node"
    done
}

# Start worker nodes
start_worker_nodes() {
    log "Starting worker nodes..."
    
    for node in "${WORKER_NODES[@]}"; do
        if ! check_node_accessibility "$node"; then
            warn "Cannot access worker node $node. Skipping..."
            continue
        fi
        
        start_node_services "$node" "worker"
        
        # Wait for worker to be ready
        wait_for_node_ready "$node" $STARTUP_TIMEOUT || {
            warn "Worker node $node did not become ready, but continuing..."
        }
        uncordon_node "$node"
    done
}

# Check cluster health
check_cluster_health() {
    local retries=$1
    local interval=$2
    
    log "Performing cluster health checks..."
    
    for ((i=1; i<=retries; i++)); do
        info "Health check attempt $i/$retries..."
        
        # Check if kubectl is working
        if ! kubectl cluster-info &>/dev/null; then
            warn "kubectl cluster-info failed on attempt $i"
            sleep $interval
            continue
        fi
        
        # Check node status
        local total_nodes=$((${#CONTROL_PLANE_NODES[@]} + ${#WORKER_NODES[@]}))
        local ready_nodes=$(kubectl get nodes --no-headers | grep -c "Ready" || echo "0")
        
        info "Ready nodes: $ready_nodes/$total_nodes"
        
        if [ "$ready_nodes" -eq "$total_nodes" ]; then
            log "All nodes are Ready!"
            break
        fi
        
        if [ $i -eq $retries ]; then
            warn "Not all nodes are ready after $retries attempts"
        else
            sleep $interval
        fi
    done
    
    # Check system pods
    info "Checking system pod status..."
    kubectl get pods -n kube-system --no-headers | while read line; do
        local pod_name=$(echo $line | awk '{print $1}')
        local status=$(echo $line | awk '{print $3}')
        
        if [[ "$status" == "Running" || "$status" == "Completed" ]]; then
            info "✓ $pod_name: $status"
        else
            warn "✗ $pod_name: $status"
        fi
    done
}

# Display cluster summary
display_cluster_summary() {
    log "Cluster startup completed! Summary:"
    echo
    
    info "Node Status:"
    kubectl get nodes -o wide || error "Failed to get node status"
    echo
    
    info "System Pod Status:"
    kubectl get pods -n kube-system || error "Failed to get system pod status"
    echo
    
    info "Cluster Info:"
    kubectl cluster-info || error "Failed to get cluster info"
    echo
    
    log "Kubeadm cluster is ready for use!"
}

# Check prerequisites
check_prerequisites() {
    # Check if kubectl is available
    if ! command -v kubectl &> /dev/null; then
        error "kubectl not found. Please install kubectl first."
        exit 1
    fi
    
    # Set kubeconfig if available
    if [ -f "/etc/kubernetes/admin.conf" ]; then
        export KUBECONFIG=/etc/kubernetes/admin.conf
        info "Using kubeconfig: /etc/kubernetes/admin.conf"
    elif [ -f "$HOME/.kube/config" ]; then
        export KUBECONFIG="$HOME/.kube/config"
        info "Using kubeconfig: $HOME/.kube/config"
    else
        warn "No kubeconfig found. You may need to set KUBECONFIG manually."
    fi
}

# Main startup sequence
main() {
    log "Starting kubeadm cluster startup sequence..."
    
    # Prerequisites
    check_prerequisites
    
    # Startup sequence
    start_control_plane_nodes
    
    # Small delay to let control plane stabilize
    info "Waiting 30 seconds for control plane to stabilize..."
    sleep 30
    
    start_worker_nodes
    
    # Health checks
    check_cluster_health $HEALTH_CHECK_RETRIES $HEALTH_CHECK_INTERVAL
    
    # Summary
    display_cluster_summary
}

# Handle script interruption
trap 'error "Startup process interrupted."' INT TERM

# Run main function
main "$@"