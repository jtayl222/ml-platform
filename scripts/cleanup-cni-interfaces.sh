#!/bin/bash
set -e

echo "=== CNI Interface Cleanup Script ==="
echo "This script will clean up stale CNI network interfaces and namespaces"
echo

# Function to clean up CNI network namespaces
cleanup_cni_namespaces() {
    echo "Cleaning up CNI network namespaces..."
    
    # List all CNI network namespaces
    local cni_netns=$(ip netns list | grep "^cni-" || true)
    
    if [ -z "$cni_netns" ]; then
        echo "  No CNI network namespaces found"
        return 0
    fi
    
    echo "  Found $(echo "$cni_netns" | wc -l) CNI network namespaces"
    
    # Delete each CNI network namespace
    while read -r netns; do
        if [ -n "$netns" ]; then
            echo "    Deleting namespace: $netns"
            ip netns delete "$netns" 2>/dev/null || echo "      Warning: Failed to delete $netns"
        fi
    done <<< "$cni_netns"
}

# Function to clean up Cilium interfaces
cleanup_cilium_interfaces() {
    echo "Cleaning up Cilium interfaces..."
    
    # Remove cilium_net, cilium_host, and cilium_vxlan interfaces
    for interface in cilium_net cilium_host cilium_vxlan; do
        if ip link show "$interface" >/dev/null 2>&1; then
            echo "  Removing interface: $interface"
            ip link delete "$interface" 2>/dev/null || echo "    Warning: Failed to delete $interface"
        fi
    done
}

# Function to clean up veth interfaces
cleanup_veth_interfaces() {
    echo "Cleaning up orphaned veth interfaces..."
    
    # Find veth interfaces that might be orphaned
    local veth_interfaces=$(ip link show | grep -E "veth[a-f0-9]+@" | awk '{print $2}' | cut -d@ -f1 || true)
    
    if [ -z "$veth_interfaces" ]; then
        echo "  No orphaned veth interfaces found"
        return 0
    fi
    
    echo "  Found potential orphaned veth interfaces: $(echo "$veth_interfaces" | wc -l)"
    
    # Don't delete veth interfaces automatically as they might be in use by Docker
    echo "  Note: veth interfaces left alone (might be used by Docker/containers)"
}

# Function to clean up bridge interfaces
cleanup_bridge_interfaces() {
    echo "Cleaning up CNI bridge interfaces..."
    
    # Look for CNI-related bridges (but be careful with Docker bridges)
    local cni_bridges=$(ip link show type bridge | grep -E "(cni|cilium)" | awk '{print $2}' | cut -d: -f1 || true)
    
    if [ -z "$cni_bridges" ]; then
        echo "  No CNI bridge interfaces found"
        return 0
    fi
    
    while read -r bridge; do
        if [ -n "$bridge" ]; then
            echo "  Removing bridge: $bridge"
            ip link delete "$bridge" 2>/dev/null || echo "    Warning: Failed to delete $bridge"
        fi
    done <<< "$cni_bridges"
}

# Function to flush iptables rules related to CNI/Cilium
cleanup_iptables_rules() {
    echo "Cleaning up iptables rules..."
    
    # Flush chains that might contain CNI/Cilium rules
    for table in filter nat mangle; do
        echo "  Flushing $table table..."
        iptables -t $table -F 2>/dev/null || true
        iptables -t $table -X 2>/dev/null || true
    done
    
    # Reset default policies
    iptables -P INPUT ACCEPT 2>/dev/null || true
    iptables -P FORWARD ACCEPT 2>/dev/null || true
    iptables -P OUTPUT ACCEPT 2>/dev/null || true
}

# Function to clean up routes
cleanup_routes() {
    echo "Cleaning up CNI-related routes..."
    
    # Remove routes to CNI networks (typically 10.244.0.0/16 for many CNIs)
    local cni_routes=$(ip route show | grep -E "(10\.244\.|cilium)" || true)
    
    if [ -n "$cni_routes" ]; then
        echo "  Found CNI-related routes:"
        echo "$cni_routes" | sed 's/^/    /'
        
        # Remove each route
        while read -r route; do
            if [ -n "$route" ]; then
                echo "    Removing route: $route"
                ip route del $route 2>/dev/null || echo "      Warning: Failed to remove route"
            fi
        done <<< "$cni_routes"
    else
        echo "  No CNI-related routes found"
    fi
}

# Function to stop and disable CNI-related services
cleanup_services() {
    echo "Cleaning up CNI-related services..."
    
    # Stop cilium agent if running
    if systemctl is-active --quiet cilium 2>/dev/null; then
        echo "  Stopping cilium service..."
        systemctl stop cilium 2>/dev/null || true
        systemctl disable cilium 2>/dev/null || true
    fi
    
    # Clean up any other CNI-related services
    for service in cilium-agent flannel; do
        if systemctl is-active --quiet $service 2>/dev/null; then
            echo "  Stopping $service service..."
            systemctl stop $service 2>/dev/null || true
            systemctl disable $service 2>/dev/null || true
        fi
    done
}

# Function to clean up CNI configuration files
cleanup_cni_configs() {
    echo "Cleaning up CNI configuration files..."
    
    # Common CNI config directories
    local cni_dirs="/etc/cni/net.d /opt/cni/bin /var/lib/cni"
    
    for dir in $cni_dirs; do
        if [ -d "$dir" ]; then
            echo "  Cleaning directory: $dir"
            find "$dir" -name "*.conf" -delete 2>/dev/null || true
            find "$dir" -name "*.conflist" -delete 2>/dev/null || true
            # Remove cilium-specific files
            find "$dir" -name "*cilium*" -delete 2>/dev/null || true
            find "$dir" -name "*flannel*" -delete 2>/dev/null || true
        fi
    done
}

# Main cleanup function
main() {
    echo "Starting CNI cleanup on $(hostname)..."
    echo "Current user: $(whoami)"
    echo
    
    # Check if running as root
    if [ "$EUID" -ne 0 ]; then
        echo "Error: This script must be run as root (use sudo)"
        exit 1
    fi
    
    # Perform cleanup steps
    cleanup_services
    cleanup_cni_namespaces
    cleanup_cilium_interfaces
    cleanup_veth_interfaces
    cleanup_bridge_interfaces
    cleanup_routes
    cleanup_iptables_rules
    cleanup_cni_configs
    
    echo
    echo "CNI cleanup completed on $(hostname)"
    echo "Remaining network interfaces:"
    ip link show | grep -E "(cilium|cni|veth)" || echo "  No CNI interfaces remaining"
    
    echo
    echo "Remaining network namespaces:"
    ip netns list | grep "cni-" || echo "  No CNI namespaces remaining"
}

# Run main function
main "$@"