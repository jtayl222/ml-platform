#!/bin/bash

echo "🗑️  Removing kubeadm cluster and cleaning up storage..."

# Remove kubeadm cluster and cleanup storage in one command
ansible-playbook -i inventory/production/hosts-kubeadm infrastructure/cluster/site.yml \
  --extra-vars="kubernetes_state=absent kubeadm_state=absent platform_type=kubeadm"

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

# Additional cleanup for container images and network rules
echo "🧹 Final cleanup of container images and network rules..."
ansible kubeadm_control_plane,kubeadm_workers -i inventory/production/hosts-kubeadm -m shell -a "
  # Stop containerd to kill remaining containers
  sudo systemctl stop containerd 2>/dev/null || true;
  
  # Remove remaining container images and snapshots
  sudo crictl rmi --all 2>/dev/null || true;
  sudo rm -rf /var/lib/containerd/io.containerd.snapshotter.v1.overlayfs/snapshots/* 2>/dev/null || true;
  
  # Clean up CNI and network interfaces
  sudo rm -rf /etc/cni/net.d/* 2>/dev/null || true;
  sudo ip link delete cilium_host 2>/dev/null || true;
  sudo ip link delete cilium_net 2>/dev/null || true;
  sudo ip link delete cilium_vxlan 2>/dev/null || true
" --become

echo "✅ kubeadm cluster cleanup complete!"
echo ""
echo "💡 Manual cleanup steps if needed:"
echo "   - Verify all nodes are clean: kubectl get nodes"
echo "   - Check container runtime: sudo crictl ps -a"
echo "   - Verify network interfaces: ip link show"