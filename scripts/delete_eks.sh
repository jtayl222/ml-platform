#!/bin/bash

echo "🗑️  Removing EKS cluster and cleaning up AWS resources..."

# Check prerequisites
command -v aws >/dev/null 2>&1 || { echo "❌ AWS CLI required"; exit 1; }
command -v eksctl >/dev/null 2>&1 || { echo "❌ eksctl required"; exit 1; }

# Check AWS credentials
aws sts get-caller-identity >/dev/null 2>&1 || { echo "❌ AWS credentials not configured"; exit 1; }

# Clean up platform services first to release AWS LoadBalancers
echo "🧹 Cleaning up platform services..."
ansible-playbook -i inventory/production/hosts-eks infrastructure/cluster/site-multiplatform.yml \
  --tags platform --extra-vars="platform_state=absent" || echo "Platform cleanup completed with warnings"

# Clean up monitoring stack
echo "📊 Cleaning up monitoring stack..."
ansible-playbook -i inventory/production/hosts-eks infrastructure/cluster/site-multiplatform.yml \
  --tags monitoring --extra-vars="monitoring_state=absent" || echo "Monitoring cleanup completed with warnings"

# Remove EKS cluster
echo "☁️  Removing EKS cluster..."
ansible-playbook -i inventory/production/hosts-eks infrastructure/cluster/site-multiplatform.yml \
  --extra-vars="eks_state=absent"

# Clean up local kubeconfig
echo "🧹 Cleaning up local kubeconfig..."
rm -f /tmp/k3s-kubeconfig.yaml ~/.kube/config

# Verify AWS resource cleanup
echo "🔍 Checking for remaining AWS resources..."
echo "Load Balancers:"
aws elbv2 describe-load-balancers --query 'LoadBalancers[?contains(LoadBalancerName, `k8s`) || contains(Tags[?Key==`kubernetes.io/cluster`], `true`)].{Name:LoadBalancerName,State:State.Code}' --output table 2>/dev/null || echo "No load balancers found"

echo ""
echo "EBS Volumes:"  
aws ec2 describe-volumes --filters "Name=tag:kubernetes.io/cluster/*,Values=owned" --query 'Volumes[].{VolumeId:VolumeId,State:State,Size:Size}' --output table 2>/dev/null || echo "No tagged volumes found"

echo ""
echo "Security Groups:"
aws ec2 describe-security-groups --filters "Name=group-name,Values=*eks*" --query 'SecurityGroups[].{GroupId:GroupId,GroupName:GroupName}' --output table 2>/dev/null || echo "No EKS security groups found"

echo ""
echo "✅ EKS cluster cleanup complete!"
echo ""
echo "⚠️  Manual cleanup if needed:"
echo "   - Check AWS Console for any remaining resources"
echo "   - Verify no unexpected charges in Cost Explorer"
echo "   - Delete any remaining EBS volumes if safe to do so"
echo "   - Check Route53 records if using custom domains"
echo ""
echo "💰 Cost verification:"
echo "   aws ce get-cost-and-usage --time-period Start=$(date -d '7 days ago' +%Y-%m-%d),End=$(date +%Y-%m-%d) --granularity DAILY --metrics BlendedCost"