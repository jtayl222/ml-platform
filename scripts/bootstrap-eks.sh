#!/bin/bash
set -e

echo "🚀 Bootstrapping MLOps Platform on EKS..."

# Check prerequisites
command -v ansible-playbook >/dev/null 2>&1 || { echo "❌ Ansible required"; exit 1; }
command -v kubectl >/dev/null 2>&1 || { echo "❌ kubectl required"; exit 1; }
command -v helm >/dev/null 2>&1 || { echo "❌ Helm required"; exit 1; }
command -v aws >/dev/null 2>&1 || { echo "❌ AWS CLI required"; exit 1; }
command -v eksctl >/dev/null 2>&1 || { echo "❌ eksctl required"; exit 1; }

# Check AWS credentials
aws sts get-caller-identity >/dev/null 2>&1 || { echo "❌ AWS credentials not configured"; exit 1; }

# Deploy EKS infrastructure
echo "☁️  Deploying EKS cluster..."
ansible-playbook -i inventory/production/hosts-eks infrastructure/cluster/site-multiplatform.yml

# Wait for cluster to be ready
echo "⏳ Waiting for EKS cluster to be ready..."
export KUBECONFIG=/tmp/k3s-kubeconfig.yaml
kubectl wait --for=condition=Ready nodes --all --timeout=900s

# Install AWS Load Balancer Controller
echo "⚖️  Installing AWS Load Balancer Controller..."
ansible-playbook -i inventory/production/hosts-eks infrastructure/cluster/site-multiplatform.yml --tags aws-load-balancer

# Install monitoring stack
echo "📊 Installing monitoring stack..."
ansible-playbook -i inventory/production/hosts-eks infrastructure/cluster/site-multiplatform.yml --tags monitoring

# Deploy MLOps components  
echo "🤖 Deploying MLOps platform..."
ansible-playbook -i inventory/production/hosts-eks infrastructure/cluster/site-multiplatform.yml --tags mlops

# Deploy platform services
echo "🔧 Deploying platform services..."
ansible-playbook -i inventory/production/hosts-eks infrastructure/cluster/site-multiplatform.yml --tags platform

echo "✅ MLOps platform ready on EKS!"
echo ""
echo "🌐 Getting service endpoints..."
echo "   MLflow:        $(kubectl get svc mlflow-service -n mlflow -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo 'Pending...')"
echo "   Grafana:       $(kubectl get svc prometheus-grafana -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo 'Pending...')"  
echo "   Harbor:        $(kubectl get svc harbor-core -n harbor -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo 'Pending...')"
echo "   Argo CD:       $(kubectl get svc argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo 'Pending...')"
echo ""
echo "💰 Cost Optimization:"
echo "   - Use spot instances for worker nodes"
echo "   - Monitor costs with AWS Cost Explorer" 
echo "   - Consider cluster auto-scaling"
echo ""
echo "💡 Access your cluster:"
echo "   aws eks update-kubeconfig --region \$AWS_REGION --name \$CLUSTER_NAME"