#!/bin/bash

# Update /etc/hosts with stable LoadBalancer IPs
# ================================================

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Updating /etc/hosts with Stable IPs${NC}"
echo -e "${BLUE}========================================${NC}\n"

# Check if running with sudo
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}This script must be run with sudo${NC}"
   echo "Usage: sudo $0"
   exit 1
fi

# Backup current hosts file
cp /etc/hosts /etc/hosts.backup.$(date +%Y%m%d-%H%M%S)
echo -e "${GREEN}✓ Created backup of /etc/hosts${NC}"

# Define the new hosts entries
cat > /tmp/k8s-hosts-new <<'EOF'
# Kubernetes homelab services begin
# MetalLB LoadBalancer IPs (Stable Assignments)
192.168.1.200   minio.test
192.168.1.201   seldon-scheduler.test
192.168.1.202   seldon-mesh.test
192.168.1.204   argocd-server.test
192.168.1.205   argo-workflows-server.test
192.168.1.206   jupyterhub.test
192.168.1.207   grafana.test
192.168.1.208   dashboard.test
192.168.1.209   prometheus-pushgateway-lb.test
192.168.1.210   harbor.test
192.168.1.215   mlflow.test

# Application Seldon Services
192.168.1.220   financial-inference-scheduler.test
192.168.1.221   financial-inference-mesh.test
192.168.1.222   financial-mlops-scheduler.test
192.168.1.223   financial-mlops-mesh.test
192.168.1.224   fraud-detection-scheduler.test
192.168.1.225   fraud-detection-mesh.test

# Istio Gateway
192.168.1.240   istio-gateway.test
192.168.1.240   fraud-detection.local
192.168.1.240   fraud-detection.test
192.168.1.241   kiali.test
192.168.1.242   jaeger.test

# NGINX Ingress
192.168.1.249   ingress-nginx-controller.test
192.168.1.249   ml-api.test
192.168.1.249   financial-predictor.test

# Kubernetes homelab services end
EOF

# Remove old Kubernetes entries
sed -i '/# Kubernetes homelab services begin/,/# Kubernetes homelab services end/d' /etc/hosts

# Append new entries
cat /tmp/k8s-hosts-new >> /etc/hosts
rm /tmp/k8s-hosts-new

echo -e "${GREEN}✓ Updated /etc/hosts with stable IPs${NC}"

# Show changes
echo -e "\n${BLUE}=== Key Changes ===${NC}"
echo -e "${YELLOW}MLflow moved from 192.168.1.203 → 192.168.1.215${NC}"
echo -e "Added dedicated IPs for application Seldon services"
echo -e "Added Kiali (192.168.1.241) and Jaeger (192.168.1.242)"

echo -e "\n${BLUE}=== Verification ===${NC}"
echo "Testing DNS resolution:"
for host in mlflow.test minio.test grafana.test argocd-server.test; do
    ip=$(getent hosts $host | awk '{print $1}')
    if [ -n "$ip" ]; then
        echo -e "  ${GREEN}✓${NC} $host → $ip"
    else
        echo -e "  ${RED}✗${NC} $host (not resolved)"
    fi
done

echo -e "\n${BLUE}=== Testing Connectivity ===${NC}"
echo "Testing MLflow endpoint:"
if curl -s --connect-timeout 2 http://mlflow.test:5000/health >/dev/null 2>&1; then
    echo -e "${GREEN}✓ MLflow is accessible at http://mlflow.test:5000${NC}"
else
    echo -e "${YELLOW}⚠ MLflow not responding (service may not be running)${NC}"
fi

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}/etc/hosts Updated Successfully!${NC}"
echo -e "${GREEN}========================================${NC}"

echo -e "\n${BLUE}Next Steps:${NC}"
echo "1. Run ./scripts/stabilize-loadbalancer-ips.sh to apply IP assignments"
echo "2. Update any bookmarks to use http://mlflow.test:5000"
echo "3. Update MLflow tracking URI in your code:"
echo "   export MLFLOW_TRACKING_URI=http://mlflow.test:5000"
echo "   # or"
echo "   export MLFLOW_TRACKING_URI=http://192.168.1.215:5000"