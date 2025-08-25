#!/bin/bash

echo "Removing K3s cluster and cleaning up storage..."

# Remove K3s cluster and cleanup NFS in one command
ansible-playbook -i inventory/production/hosts-k3s infrastructure/cluster/site.yml \
  --extra-vars="k3s_state=absent" \
  -e platform_type=k3s

# Verify NFS cleanup
echo "Verifying NFS cleanup..."
ssh 192.168.1.100 "ls -la /srv/nfs/kubernetes/ | wc -l"  # Should show 3 (., .., empty)

echo "Cleanup complete!"
