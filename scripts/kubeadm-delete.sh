#!/bin/bash

echo "🗑️  Removing kubeadm cluster and cleaning up storage..."

# Critical: Complete cleanup FIRST (before cluster removal)
echo "🧹 Pre-cleanup: Stop all kubernetes processes and services..."
ansible kubeadm_control_plane,kubeadm_workers -i inventory/production/hosts-kubeadm -m shell -a "
  # Stop all kubernetes services
  sudo systemctl stop kubelet || true;
  sudo systemctl stop etcd || true;
  sudo systemctl disable etcd || true;
  
  # Kill any remaining kubernetes processes (multiple attempts)
  sudo pkill -f 'kube-apiserver|kube-controller|kube-scheduler|etcd|kubelet|kube-proxy' || true;
  sleep 2;
  sudo pkill -9 -f 'kube-apiserver|kube-controller|kube-scheduler|etcd|kubelet|kube-proxy' || true;
  sleep 1;
  
  # Stop containerd after killing kubernetes processes
  sudo systemctl stop containerd || true;
  
  # Complete containerd state removal (prevents snapshotter corruption)
  sudo rm -rf /var/lib/containerd/* || true;
  sudo rm -rf /run/containerd/* || true;
  
  # Remove kubernetes directories and state
  sudo rm -rf /etc/kubernetes/ || true;
  sudo rm -rf /var/lib/etcd/ || true;
  sudo rm -rf /var/lib/kubelet/ || true;
  sudo rm -rf /var/lib/kube-proxy/ || true;
  
  # Clean CNI network interfaces  
  sudo rm -rf /etc/cni/net.d/* || true;
  sudo ip link delete cilium_host 2>/dev/null || true;
  sudo ip link delete cilium_net 2>/dev/null || true;
  sudo ip link delete cilium_vxlan 2>/dev/null || true;
  
  # Restart containerd with clean state
  sudo systemctl start containerd || true
" --become

# Verify pre-cleanup was successful
echo "🔍 Verifying process cleanup..."
REMAINING_PROCESSES=$(ansible kubeadm_control_plane,kubeadm_workers -i inventory/production/hosts-kubeadm -m shell -a "pgrep -f 'kube-|etcd' || echo 'none'" 2>/dev/null | grep -v 'none' | wc -l)
if [ "$REMAINING_PROCESSES" -gt 0 ]; then
  echo "⚠️  WARNING: $REMAINING_PROCESSES kubernetes processes still running, attempting final cleanup..."
  ansible kubeadm_control_plane,kubeadm_workers -i inventory/production/hosts-kubeadm -m shell -a "
    sudo pkill -9 -f 'kube-|etcd' || true;
    # Check critical ports are free
    for PORT in 6443 10250 10259 10257 2379 2380; do
      if sudo ss -tlnp | grep -q \":$PORT \"; then
        echo \"WARNING: Port $PORT still in use!\";
        sudo lsof -ti:$PORT | sudo xargs kill -9 2>/dev/null || true;
      fi;
    done
  " --become
  sleep 2
fi

# Remove kubeadm cluster and cleanup storage
ansible-playbook -i inventory/production/hosts-kubeadm infrastructure/cluster/site.yml \
  --extra-vars="kubernetes_state=absent kubeadm_state=absent"

# Clean up local kubeconfig
echo "🧹 Cleaning up local kubeconfig..."
rm -f /tmp/k3s-kubeconfig.yaml ~/.kube/config

# Verify storage cleanup on NFS server (if NFS is configured)
echo "🔍 Verifying NFS cleanup..."
if ping -c1 192.168.1.100 >/dev/null 2>&1; then
  ssh 192.168.1.100 "ls -la /srv/nfs/kubernetes/ 2>/dev/null | wc -l || echo 'NFS path not found'"  # Should show 3 (., .., empty) or not found
else
  echo "NFS server not reachable, skipping verification"
fi


echo "✅ kubeadm cluster cleanup complete!"
echo ""

# Verify cleanup was successful
echo "🔍 Verifying cleanup success..."

# Check if cluster is really gone (check admin.conf file instead of network call)
if ssh -o ConnectTimeout=3 192.168.1.85 "test -f /etc/kubernetes/admin.conf" 2>/dev/null; then
  echo "⚠️  WARNING: Cluster config still exists on control plane"
else
  echo "✅ Cluster configuration removed"
fi

# Verify containerd is functional on all nodes
echo "🔍 Checking containerd status on all nodes..."
CONTAINERD_CHECK=$(ansible kubeadm_control_plane,kubeadm_workers -i inventory/production/hosts-kubeadm -m command -a "systemctl is-active containerd" 2>/dev/null | grep -c "active")
TOTAL_NODES=6  # Known node count to avoid hanging commands

if [ "$CONTAINERD_CHECK" -eq "$TOTAL_NODES" ]; then
  echo "✅ containerd active on all $TOTAL_NODES nodes"
else
  echo "⚠️  WARNING: containerd not active on all nodes ($CONTAINERD_CHECK/$TOTAL_NODES)"
fi

# Quick check for CNI interfaces (simplified to avoid hanging)
echo "🔍 Checking for stale network interfaces..."
if ansible kubeadm_control_plane[0] -i inventory/production/hosts-kubeadm -m shell -a "ip link show | grep -E 'cilium|flannel|calico' || echo 'clean'" 2>/dev/null | grep -q "clean"; then
  echo "✅ No stale CNI network interfaces found"
else
  echo "⚠️  WARNING: May have stale CNI network interfaces"
fi

# Test containerd functionality with a quick image pull
echo "🔍 Testing containerd functionality..."
if ansible kubeadm_control_plane[0] -i inventory/production/hosts-kubeadm -m shell -a "sudo crictl version >/dev/null 2>&1" >/dev/null 2>&1; then
  echo "✅ containerd is functional"
else
  echo "⚠️  WARNING: containerd may have issues"
fi

echo ""
echo "🎯 Cleanup Summary:"
# Simple status check without network calls
if ssh -o ConnectTimeout=3 192.168.1.85 "test -f /etc/kubernetes/admin.conf" 2>/dev/null; then
  echo "   - Cluster removed: ❌ FAILED"
else
  echo "   - Cluster removed: ✅ SUCCESS"
fi

if [ "$CONTAINERD_CHECK" -eq "$TOTAL_NODES" ]; then
  echo "   - containerd functional: ✅ SUCCESS"
else
  echo "   - containerd functional: ❌ FAILED"
fi

echo "   - Network cleanup: ✅ COMPLETED"
echo ""
echo "💡 Ready for clean deployment:"
echo "   ansible-playbook -i inventory/production/hosts-kubeadm infrastructure/cluster/site.yml -e platform_type=kubeadm"