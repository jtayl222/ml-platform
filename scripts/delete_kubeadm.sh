#!/bin/bash

echo "🗑️  Removing kubeadm cluster and cleaning up storage..."

# Remove kubeadm cluster and cleanup storage in one command
ansible-playbook -i inventory/production/hosts-kubeadm infrastructure/cluster/site-multiplatform.yml \
  --extra-vars="kubeadm_state=absent"

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

# Clean up any remaining container images on nodes
echo "🐳 Cleaning up container images on cluster nodes..."
ansible kubeadm_control_plane,kubeadm_workers -i inventory/production/hosts-kubeadm -m shell -a "
  sudo crictl rmi --prune 2>/dev/null || true;
  sudo systemctl stop containerd kubelet 2>/dev/null || true;
  sudo rm -rf /var/lib/containerd/io.containerd.snapshotter.v1.overlayfs/snapshots/* 2>/dev/null || true;
  sudo rm -rf /var/lib/kubelet/* 2>/dev/null || true;
  sudo rm -rf /etc/kubernetes/* 2>/dev/null || true;
  sudo rm -rf /etc/cni/net.d/* 2>/dev/null || true;
  sudo systemctl start containerd 2>/dev/null || true
" --become

echo "✅ kubeadm cluster cleanup complete!"
echo ""
echo "💡 Manual cleanup steps if needed:"
echo "   - Verify all nodes are clean: kubectl get nodes"
echo "   - Check container runtime: sudo crictl ps -a"
echo "   - Verify network interfaces: ip link show"