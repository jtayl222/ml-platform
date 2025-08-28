#!/bin/bash

# Stabilize LoadBalancer IPs for Platform Services
# ==================================================
# This script patches LoadBalancer services with stable IP assignments
# to prevent IP reassignment issues across deployments.

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}LoadBalancer IP Stabilization Script${NC}"
echo -e "${BLUE}========================================${NC}\n"

# Function to patch service with stable IP
patch_service_ip() {
    local namespace=$1
    local service=$2
    local ip=$3
    
    echo -e "${YELLOW}Patching ${service} in ${namespace} with IP ${ip}...${NC}"
    
    # Check if service exists
    if kubectl get svc "${service}" -n "${namespace}" &>/dev/null; then
        # Patch the service with the stable IP annotation
        kubectl annotate svc "${service}" -n "${namespace}" \
            "metallb.universe.tf/loadBalancer-ips=${ip}" \
            --overwrite
        
        # Force MetalLB to reassign the IP by recreating the service
        echo -e "  Forcing IP reassignment..."
        kubectl get svc "${service}" -n "${namespace}" -o yaml > /tmp/${service}-backup.yaml
        kubectl delete svc "${service}" -n "${namespace}" --wait=false
        sleep 2
        kubectl apply -f /tmp/${service}-backup.yaml
        rm -f /tmp/${service}-backup.yaml
        
        echo -e "${GREEN}  ✓ ${service} patched successfully${NC}"
    else
        echo -e "${RED}  ✗ Service ${service} not found in namespace ${namespace}${NC}"
    fi
}

# Core Infrastructure Services (200-209)
echo -e "\n${BLUE}=== Core Infrastructure Services ===${NC}"
patch_service_ip "minio" "minio" "192.168.1.200"
patch_service_ip "seldon-system" "seldon-scheduler" "192.168.1.201"
patch_service_ip "seldon-system" "seldon-mesh" "192.168.1.202"
patch_service_ip "argocd" "argocd-server" "192.168.1.204"
patch_service_ip "argowf" "argo-workflows-server" "192.168.1.205"
patch_service_ip "jupyterhub" "jupyterhub" "192.168.1.206"
patch_service_ip "monitoring" "grafana" "192.168.1.207"
patch_service_ip "kubernetes-dashboard" "dashboard" "192.168.1.208"
patch_service_ip "monitoring" "prometheus-pushgateway-lb" "192.168.1.209"

# Registry & ML Services (210-219)
echo -e "\n${BLUE}=== Registry & ML Services ===${NC}"
patch_service_ip "harbor" "harbor" "192.168.1.210" 2>/dev/null || true
patch_service_ip "mlflow" "mlflow" "192.168.1.215"

# Application-Specific Seldon Deployments (220-239)
echo -e "\n${BLUE}=== Application Seldon Services ===${NC}"
patch_service_ip "financial-inference" "seldon-scheduler" "192.168.1.220"
patch_service_ip "financial-inference" "seldon-mesh" "192.168.1.221"
patch_service_ip "financial-mlops-pytorch" "seldon-scheduler" "192.168.1.222"
patch_service_ip "financial-mlops-pytorch" "seldon-mesh" "192.168.1.223"
patch_service_ip "fraud-detection" "seldon-scheduler" "192.168.1.224"
patch_service_ip "fraud-detection" "seldon-mesh" "192.168.1.225"

# Observability & Service Mesh (240-249)
echo -e "\n${BLUE}=== Observability & Service Mesh ===${NC}"
patch_service_ip "istio-gateway" "istio-gateway" "192.168.1.240" 2>/dev/null || true
patch_service_ip "istio-system" "kiali" "192.168.1.241" 2>/dev/null || true
patch_service_ip "istio-system" "jaeger-query" "192.168.1.242" 2>/dev/null || true
patch_service_ip "ingress-nginx" "ingress-nginx-controller" "192.168.1.249" 2>/dev/null || true

echo -e "\n${BLUE}=== Verification ===${NC}"
echo "Waiting for services to stabilize (30 seconds)..."
sleep 30

echo -e "\n${BLUE}Current LoadBalancer IP Assignments:${NC}"
kubectl get svc -A | grep LoadBalancer | awk '{printf "%-30s %-40s %s\n", $1, $2, $5}' | sort -t. -k4 -n

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}IP Stabilization Complete!${NC}"
echo -e "${GREEN}========================================${NC}"

echo -e "\n${YELLOW}Important Notes:${NC}"
echo "1. These IPs are now stable and will persist across deployments"
echo "2. Update your /etc/hosts file with the new IPs if needed"
echo "3. MLflow is now accessible at: http://192.168.1.215:5000"
echo "4. Run this script after any new service deployments to ensure IP stability"