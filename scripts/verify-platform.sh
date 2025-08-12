#!/bin/bash
# MLOps Platform Verification Script
# Industry best practice: Comprehensive automated health checks

set -e

echo "🔍 MLOps Platform Verification Starting..."
echo "=============================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Verification functions
check_prerequisites() {
    echo -e "\n${BLUE}📋 Checking Prerequisites...${NC}"
    
    # Critical tools
    command -v kubectl >/dev/null 2>&1 && echo -e "✅ kubectl: $(kubectl version --client --short 2>/dev/null || echo 'available')" || echo -e "❌ kubectl: Missing"
    command -v helm >/dev/null 2>&1 && echo -e "✅ helm: $(helm version --short 2>/dev/null)" || echo -e "❌ helm: Missing"
    command -v yq >/dev/null 2>&1 && echo -e "✅ yq: $(yq --version | head -1)" || echo -e "❌ yq: Missing"
    command -v jq >/dev/null 2>&1 && echo -e "✅ jq: $(jq --version)" || echo -e "❌ jq: Missing"
}

validate_inventory() {
    echo -e "\n${BLUE}📋 Validating Inventory Configuration...${NC}"
    
    # Detect current inventory file
    local inventory_file=""
    if [ -f "inventory/production/hosts-k3s" ]; then
        inventory_file="inventory/production/hosts-k3s"
    elif [ -f "inventory/production/hosts-kubeadm" ]; then
        inventory_file="inventory/production/hosts-kubeadm"
    elif [ -f "inventory/production/hosts-eks" ]; then
        inventory_file="inventory/production/hosts-eks"
    elif [ -f "inventory/production/hosts" ]; then
        inventory_file="inventory/production/hosts"
    fi
    
    if [ -z "$inventory_file" ]; then
        echo -e "⚠️ No inventory file found"
        return
    fi
    
    echo "Using inventory: $inventory_file"
    
    # Get expected nodes from inventory
    if command -v ansible-inventory >/dev/null 2>&1; then
        echo -e "\nExpected vs Actual Nodes:"
        
        # Extract expected nodes
        local expected_nodes=$(ansible-inventory -i "$inventory_file" --list 2>/dev/null | jq -r '._meta.hostvars | keys[]' 2>/dev/null | grep -v localhost | sort)
        local actual_nodes=$(kubectl get nodes --no-headers | awk '{print $1}' | sort)
        
        # Compare nodes
        echo "Expected nodes from inventory:"
        echo "$expected_nodes" | while read node; do
            if [ -n "$node" ]; then
                if echo "$actual_nodes" | grep -q "^$node$"; then
                    echo -e "✅ $node: Present in cluster"
                else
                    echo -e "❌ $node: Missing from cluster"
                fi
            fi
        done
        
        echo -e "\nActual nodes in cluster:"
        echo "$actual_nodes" | while read node; do
            if [ -n "$node" ]; then
                if echo "$expected_nodes" | grep -q "^$node$"; then
                    echo -e "✅ $node: Matches inventory"
                else
                    echo -e "⚠️ $node: Not in inventory (may be auto-generated)"
                fi
            fi
        done
    else
        echo -e "⚠️ ansible-inventory not available, skipping detailed validation"
    fi
}

check_cluster_health() {
    echo -e "\n${BLUE}🏗️ Checking Cluster Health...${NC}"
    
    # Node status
    echo "Nodes:"
    kubectl get nodes --no-headers | while read line; do
        node=$(echo $line | awk '{print $1}')
        status=$(echo $line | awk '{print $2}')
        role=$(echo $line | awk '{print $3}')
        age=$(echo $line | awk '{print $4}')
        version=$(echo $line | awk '{print $5}')
        if [ "$status" = "Ready" ]; then
            echo -e "✅ $node: $status ($role) - age: $age, version: $version"
        else
            echo -e "❌ $node: $status ($role) - age: $age, version: $version"
        fi
    done
    
    # Pod health across namespaces
    echo -e "\nPod Health Summary:"
    kubectl get pods --all-namespaces --field-selector=status.phase!=Running,status.phase!=Succeeded --no-headers | wc -l | xargs -I {} echo -e "❌ Non-running pods: {}"
    kubectl get pods --all-namespaces --field-selector=status.phase=Running --no-headers | wc -l | xargs -I {} echo -e "✅ Running pods: {}"
    
    # Platform detection
    echo -e "\nPlatform Detection:"
    if kubectl get nodes -o jsonpath='{.items[0].status.nodeInfo.containerRuntimeVersion}' | grep -q containerd; then
        if kubectl get nodes -o jsonpath='{.items[0].metadata.labels}' | grep -q k3s; then
            echo -e "✅ Detected Platform: K3s"
        elif ls /etc/kubernetes/admin.conf >/dev/null 2>&1 || kubectl get nodes -o jsonpath='{.items[0].metadata.labels}' | grep -q kubeadm; then
            echo -e "✅ Detected Platform: Kubeadm"
        else
            echo -e "✅ Detected Platform: Generic Kubernetes"
        fi
    else
        echo -e "⚠️ Unknown container runtime"
    fi
}

check_core_services() {
    echo -e "\n${BLUE}🔧 Checking Core Services...${NC}"
    
    # Storage
    kubectl get pv,pvc --all-namespaces >/dev/null 2>&1 && echo -e "✅ Storage: PVs and PVCs accessible" || echo -e "❌ Storage: Issues detected"
    
    # MetalLB
    kubectl get pods -n metallb-system --no-headers 2>/dev/null | grep -q "Running" && echo -e "✅ MetalLB: Running" || echo -e "⚠️ MetalLB: Not running or not installed"
    
    # Sealed Secrets
    kubectl get pods -n sealed-secrets --no-headers 2>/dev/null | grep -q "Running" && echo -e "✅ Sealed Secrets: Running" || echo -e "❌ Sealed Secrets: Not running"
}

check_service_mesh() {
    echo -e "\n${BLUE}🕸️ Checking Service Mesh...${NC}"
    
    # Istio
    kubectl get pods -n istio-system --no-headers 2>/dev/null | grep -q "Running" && echo -e "✅ Istio: Control plane running" || echo -e "⚠️ Istio: Not running or not installed"
    
    # Kiali
    kubectl get pods -n istio-system -l app=kiali --no-headers 2>/dev/null | grep -q "Running" && echo -e "✅ Kiali: Observability dashboard running" || echo -e "⚠️ Kiali: Not running"
    
    # Gateway
    kubectl get pods -n istio-gateway --no-headers 2>/dev/null | grep -q "Running" && echo -e "✅ Istio Gateway: Running" || echo -e "⚠️ Istio Gateway: Not running"
}

check_mlops_stack() {
    echo -e "\n${BLUE}🤖 Checking MLOps Stack...${NC}"
    
    # MLflow
    kubectl get pods -n mlflow --no-headers 2>/dev/null | grep -q "Running" && echo -e "✅ MLflow: Experiment tracking running" || echo -e "❌ MLflow: Not running"
    
    # Seldon Core
    kubectl get pods -n seldon-system --no-headers 2>/dev/null | grep -q "Running" && echo -e "✅ Seldon Core: Model serving running" || echo -e "❌ Seldon Core: Not running"
    
    # JupyterHub
    kubectl get pods -n jupyterhub --no-headers 2>/dev/null | grep -q "Running" && echo -e "✅ JupyterHub: Collaborative environment running" || echo -e "❌ JupyterHub: Not running"
}

check_devops_stack() {
    echo -e "\n${BLUE}🚀 Checking DevOps Stack...${NC}"
    
    # Argo CD
    kubectl get pods -n argocd --no-headers 2>/dev/null | grep -q "Running" && echo -e "✅ Argo CD: GitOps running" || echo -e "❌ Argo CD: Not running"
    
    # Argo Workflows
    kubectl get pods -n argowf --no-headers 2>/dev/null | grep -q "Running" && echo -e "✅ Argo Workflows: Pipeline automation running" || echo -e "❌ Argo Workflows: Not running"
    
    # Harbor
    kubectl get pods -n harbor --no-headers 2>/dev/null | grep -q "Running" && echo -e "✅ Harbor: Container registry running" || echo -e "❌ Harbor: Not running"
}

check_monitoring() {
    echo -e "\n${BLUE}📊 Checking Monitoring Stack...${NC}"
    
    # Prometheus
    kubectl get pods -n monitoring --no-headers 2>/dev/null | grep prometheus | grep -q "Running" && echo -e "✅ Prometheus: Metrics collection running" || echo -e "❌ Prometheus: Not running"
    
    # Grafana
    kubectl get pods -n monitoring --no-headers 2>/dev/null | grep grafana | grep -q "Running" && echo -e "✅ Grafana: Dashboards running" || echo -e "❌ Grafana: Not running"
    
    # MinIO
    kubectl get pods -n minio --no-headers 2>/dev/null | grep -q "Running" && echo -e "✅ MinIO: Object storage running" || echo -e "❌ MinIO: Not running"
}

check_service_endpoints() {
    echo -e "\n${BLUE}🌐 Checking Service Endpoints...${NC}"
    
    # LoadBalancer services
    echo "LoadBalancer Services:"
    kubectl get svc --all-namespaces --field-selector spec.type=LoadBalancer --no-headers | while read line; do
        namespace=$(echo $line | awk '{print $1}')
        service=$(echo $line | awk '{print $2}')
        external_ip=$(echo $line | awk '{print $4}')
        if [ "$external_ip" != "<pending>" ] && [ "$external_ip" != "<none>" ]; then
            echo -e "✅ $namespace/$service: $external_ip"
        else
            echo -e "⚠️ $namespace/$service: $external_ip"
        fi
    done
}

test_ml_workflow() {
    echo -e "\n${BLUE}🧪 Testing ML Workflow...${NC}"
    
    # Test basic connectivity to MLflow
    MLFLOW_URL="http://192.168.1.201:5000"
    if command -v curl >/dev/null 2>&1; then
        if curl -s --connect-timeout 5 "$MLFLOW_URL" >/dev/null; then
            echo -e "✅ MLflow API: Accessible at $MLFLOW_URL"
        else
            echo -e "⚠️ MLflow API: Not accessible (check NodePort or LoadBalancer)"
        fi
    fi
    
    # Test MinIO S3 API
    MINIO_URL="http://192.168.1.200:9000"
    if curl -s --connect-timeout 5 "$MINIO_URL/minio/health/live" >/dev/null; then
        echo -e "✅ MinIO API: Healthy at $MINIO_URL"
    else
        echo -e "⚠️ MinIO API: Not accessible"
    fi
}

generate_summary() {
    echo -e "\n${BLUE}📋 Platform Summary${NC}"
    echo "===================="
    
    # Count running pods per namespace
    echo "Running Pods by Namespace:"
    kubectl get pods --all-namespaces --field-selector=status.phase=Running --no-headers | awk '{print $1}' | sort | uniq -c | sort -nr
    
    echo -e "\n🎯 Key Service URLs:"
    echo "- MLflow: http://192.168.1.201:5000 (LoadBalancer) or http://<node-ip>:30800 (NodePort)"
    echo "- Kiali: http://192.168.1.211:20001 (LoadBalancer) or http://<node-ip>:32001 (NodePort)"
    echo "- Harbor: http://192.168.1.210:80 (LoadBalancer) or http://<node-ip>:30880 (NodePort)"
    echo "- Grafana: http://192.168.1.207:3000 (LoadBalancer) or http://<node-ip>:30300 (NodePort)"
    echo "- JupyterHub: http://192.168.1.206:80 (LoadBalancer) or http://<node-ip>:30888 (NodePort)"
}

# Main execution
main() {
    check_prerequisites
    validate_inventory
    check_cluster_health
    check_core_services
    check_service_mesh
    check_mlops_stack
    check_devops_stack
    check_monitoring
    check_service_endpoints
    test_ml_workflow
    generate_summary
    
    echo -e "\n${GREEN}🎉 Platform verification complete!${NC}"
    echo "For detailed troubleshooting, run: kubectl get pods --all-namespaces"
}

# Run verification
main "$@"