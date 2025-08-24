#!/bin/bash
set -e

echo "🚀 Bootstrapping MLOps Platform with kubeadm (simple single control plane)..."

# Deploy single control plane
echo "📦 Deploying kubeadm single control plane..."
ansible-playbook -i inventory/production/hosts-kubeadm infrastructure/cluster/site.yml --limit "nuc10i3-1,localhost" --tags kubeadm

# Fetch kubeconfig
echo "📥 Fetching kubeconfig..."
ansible-playbook -i inventory/production/hosts-kubeadm infrastructure/cluster/site.yml --tags kubeconfig

# Install CNI
echo "🌐 Installing Cilium CNI..."
export KUBECONFIG=/home/user/REPOS/ml-platform/infrastructure/fetched_tokens/kubeconfig-kubeadm
helm repo update
helm install cilium cilium/cilium --version 1.18.0 --namespace kube-system \
  --set ipam.mode=kubernetes \
  --set kubeProxyReplacement=false \
  --set k8sServiceHost=192.168.1.103 \
  --set k8sServicePort=6443

# Wait for node to be ready
echo "⏳ Waiting for node to be ready..."
kubectl wait --for=condition=Ready node nuc10i3-1 --timeout=300s

# Join worker nodes manually
echo "🔧 Joining worker nodes..."
JOIN_CMD=$(ssh 192.168.1.103 "sudo kubeadm token create --print-join-command")
ansible kubeadm_workers -i inventory/production/hosts-kubeadm -m shell -a "sudo kubeadm reset --force && sudo $JOIN_CMD" --become

echo "✅ Basic kubeadm cluster ready!"
kubectl get nodes