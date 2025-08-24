#!/bin/bash

# kubeadm_shutdown.sh
# Graceful shutdown script for kubeadm-based Kubernetes cluster
# Handles proper pod eviction and node shutdown sequence

set -euo pipefail

# Configuration
DRAIN_TIMEOUT="300s"
DELETE_TIMEOUT="60s"
CONTROL_PLANE_NODES=("192.168.1.85" "192.168.1.103" "192.168.1.104")
WORKER_NODES=("192.168.1.105" "192.168.1.107" "192.168.1.108")

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
}

# Check if kubectl is available and cluster is accessible
check_cluster_access() {
    if ! command -v kubectl &> /dev/null; then
        error "kubectl not found. Please install kubectl first."
        exit 1
    fi

    if ! kubectl cluster-info &> /dev/null; then
        error "Cannot access Kubernetes cluster. Check your kubeconfig."
        exit 1
    fi
}

# Drain worker nodes
drain_worker_nodes() {
    log "Starting worker node drain process..."
    
    for node in "${WORKER_NODES[@]}"; do
        if kubectl get node "$node" &> /dev/null; then
            log "Draining worker node: $node"
            kubectl drain "$node" \
                --ignore-daemonsets \
                --delete-emptydir-data \
                --force \
                --timeout="$DRAIN_TIMEOUT" || warn "Failed to drain $node completely"
        else
            warn "Worker node $node not found in cluster"
        fi
    done
}

# Delete remaining pods forcefully if needed
force_delete_pods() {
    log "Checking for remaining pods..."
    
    # Get all pods except those in kube-system and those that should remain
    REMAINING_PODS=$(kubectl get pods --all-namespaces \
        --field-selector=status.phase!=Succeeded,status.phase!=Failed \
        --no-headers | grep -v kube-system | grep -v "Terminating" | wc -l || echo "0")
    
    if [ "$REMAINING_PODS" -gt 0 ]; then
        warn "Found $REMAINING_PODS remaining pods. Attempting graceful deletion..."
        
        kubectl get pods --all-namespaces \
            --field-selector=status.phase!=Succeeded,status.phase!=Failed \
            --no-headers | grep -v kube-system | while read namespace name rest; do
            log "Deleting pod $name in namespace $namespace"
            kubectl delete pod "$name" -n "$namespace" --timeout="$DELETE_TIMEOUT" --force || true
        done
    fi
}

# Shutdown worker nodes
shutdown_worker_nodes() {
    log "Shutting down worker nodes..."
    
    for node in "${WORKER_NODES[@]}"; do
        log "Shutting down worker node: $node"
        ssh "$node" "sudo shutdown -h now" || warn "Failed to shutdown $node via SSH"
    done
    
    # Wait for worker nodes to shutdown
    log "Waiting for worker nodes to shutdown..."
    sleep 30
}

# Drain control plane node
drain_control_plane() {
    log "Draining control plane nodes..."
    
    for node in "${CONTROL_PLANE_NODES[@]}"; do
        if kubectl get node "$node" &> /dev/null; then
            log "Draining control plane node: $node"
            kubectl drain "$node" \
                --ignore-daemonsets \
                --delete-emptydir-data \
                --force \
                --timeout="$DRAIN_TIMEOUT" || warn "Failed to drain $node completely"
        else
            warn "Control plane node $node not found in cluster"
        fi
    done
}

# Stop kubelet and container runtime on control plane
stop_control_plane_services() {
    log "Stopping control plane services..."
    
    for node in "${CONTROL_PLANE_NODES[@]}"; do
        log "Stopping services on control plane node: $node"
        ssh "$node" "sudo systemctl stop kubelet" || warn "Failed to stop kubelet on $node"
        ssh "$node" "sudo systemctl stop containerd" || warn "Failed to stop containerd on $node"
        ssh "$node" "sudo systemctl stop docker" 2>/dev/null || true  # Docker might not be running
    done
}

# Shutdown control plane nodes
shutdown_control_plane() {
    log "Shutting down control plane nodes..."
    
    for node in "${CONTROL_PLANE_NODES[@]}"; do
        log "Shutting down control plane node: $node"
        ssh "$node" "sudo shutdown -h now" || warn "Failed to shutdown $node via SSH"
    done
}

# Main shutdown sequence
main() {
    log "Starting kubeadm cluster shutdown sequence..."
    
    # Pre-flight checks
    check_cluster_access
    
    # Shutdown sequence
    drain_worker_nodes
    force_delete_pods
    shutdown_worker_nodes
    drain_control_plane
    stop_control_plane_services
    shutdown_control_plane
    
    log "Cluster shutdown sequence completed successfully!"
    log "All nodes should be shutting down. Wait a few minutes before powering off if needed."
}

# Handle script interruption
trap 'error "Shutdown process interrupted. Cluster may be in inconsistent state."' INT TERM

# Run main function
main "$@"
