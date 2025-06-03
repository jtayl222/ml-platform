#!/bin/bash
set -e

echo "🚀 Bootstrapping MLOps Platform..."

# Check prerequisites
command -v ansible-playbook >/dev/null 2>&1 || { echo "❌ Ansible required"; exit 1; }
command -v kubectl >/dev/null 2>&1 || { echo "❌ kubectl required"; exit 1; }
command -v helm >/dev/null 2>&1 || { echo "❌ Helm required"; exit 1; }

# Deploy infrastructure
echo "📦 Deploying K3s cluster..."
ansible-playbook -i inventory/production/hosts infrastructure/cluster/site.yml

# Wait for cluster to be ready
echo "⏳ Waiting for cluster to be ready..."
kubectl wait --for=condition=Ready nodes --all --timeout=300s

# Install Helm charts
echo "📊 Installing monitoring stack..."
ansible-playbook -i inventory/production/hosts infrastructure/cluster/site.yml --tags monitoring

# Deploy MLOps components  
echo "🤖 Deploying MLOps platform..."
ansible-playbook -i inventory/production/hosts infrastructure/cluster/site.yml --tags mlops

echo "✅ MLOps platform ready!"
echo "🌐 Access Grafana: http://$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[0].address}'):30300"
echo "🔬 Access MLflow: http://$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[0].address}'):30800"