#!/bin/bash
set -e

echo "🚀 Bootstrapping MLOps Platform with kubeadm..."

# Check prerequisites
command -v ansible-playbook >/dev/null 2>&1 || { echo "❌ Ansible required"; exit 1; }
command -v kubectl >/dev/null 2>&1 || { echo "❌ kubectl required"; exit 1; }
command -v helm >/dev/null 2>&1 || { echo "❌ Helm required"; exit 1; }

# Deploy infrastructure
echo "📦 Deploying kubeadm cluster..."
ansible-playbook -i inventory/production/hosts-kubeadm infrastructure/cluster/site-multiplatform.yml

# Wait for cluster to be ready
echo "⏳ Waiting for cluster to be ready..."
export KUBECONFIG=/home/user/REPOS/ml-platform/infrastructure/fetched_tokens/kubeconfig-kubeadm
kubectl wait --for=condition=Ready nodes --all --timeout=600s

# Install CNI (Cilium)
echo "🌐 Installing Cilium CNI..."
ansible-playbook -i inventory/production/hosts-kubeadm infrastructure/cluster/site-multiplatform.yml --tags cni

# Install Helm charts
echo "📊 Installing monitoring stack..."
ansible-playbook -i inventory/production/hosts-kubeadm infrastructure/cluster/site-multiplatform.yml --tags monitoring

# Deploy MLOps components  
echo "🤖 Deploying MLOps platform..."
ansible-playbook -i inventory/production/hosts-kubeadm infrastructure/cluster/site-multiplatform.yml --tags mlops

# Deploy platform services
echo "🔧 Deploying platform services..."
ansible-playbook -i inventory/production/hosts-kubeadm infrastructure/cluster/site-multiplatform.yml --tags platform

echo "✅ MLOps platform ready!"
echo ""
echo "🌐 Platform Access (LoadBalancer endpoints):"
echo "   MLflow:        http://192.168.1.201:5000"
echo "   Grafana:       http://192.168.1.207:3000" 
echo "   Harbor:        http://192.168.1.210"
echo "   Argo CD:       http://192.168.1.204"
echo "   JupyterHub:    http://192.168.1.206"
echo ""
echo "🔧 Platform Access (NodePort fallback):"
echo "   MLflow:        http://$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[0].address}'):30800"
echo "   Grafana:       http://$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[0].address}'):30300"
echo "   Harbor:        http://$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[0].address}'):30880"
echo ""
echo "💡 Add entries to /etc/hosts for easy access:"
echo "   192.168.1.201 mlflow.test"
echo "   192.168.1.207 grafana.test" 
echo "   192.168.1.210 harbor.test"