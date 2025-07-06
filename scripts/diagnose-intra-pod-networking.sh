#!/bin/bash
# K3s Intra-Pod Networking Diagnostic Script

set -e

POD_NAME="${1:-mlserver-0}"
NAMESPACE="${2:-financial-ml}"
AGENT_CONTAINER="${3:-agent}"
SERVER_CONTAINER="${4:-mlserver}"

echo "=== K3s Intra-Pod Networking Diagnostics ==="
echo "Pod: $POD_NAME"
echo "Namespace: $NAMESPACE"
echo "Agent Container: $AGENT_CONTAINER"
echo "Server Container: $SERVER_CONTAINER"
echo

echo "1. Pod Status and IP Information"
echo "================================"
kubectl get pod $POD_NAME -n $NAMESPACE -o wide
echo

echo "2. Container Network Namespace Verification"
echo "==========================================="
echo "Agent container network interfaces:"
kubectl exec $POD_NAME -c $AGENT_CONTAINER -n $NAMESPACE -- ip addr show lo
echo
echo "Server container network interfaces:"
kubectl exec $POD_NAME -c $SERVER_CONTAINER -n $NAMESPACE -- ip addr show lo
echo

echo "3. Network Namespace IDs (should be identical)"
echo "=============================================="
POD_ID=$(kubectl get pod $POD_NAME -n $NAMESPACE -o jsonpath='{.status.containerStatuses[0].containerID}' | cut -d'/' -f3)
echo "Pod container ID: $POD_ID"

if command -v crictl &> /dev/null; then
    echo "Container network namespaces:"
    crictl inspect $POD_ID 2>/dev/null | grep -i netns || echo "Could not retrieve netns info"
else
    echo "crictl not available - cannot check container namespaces"
fi
echo

echo "4. Port Binding Verification"
echo "============================"
echo "Ports bound in server container:"
kubectl exec $POD_NAME -c $SERVER_CONTAINER -n $NAMESPACE -- netstat -tlpn 2>/dev/null || kubectl exec $POD_NAME -c $SERVER_CONTAINER -n $NAMESPACE -- ss -tlpn
echo

echo "5. Localhost Connectivity Test"
echo "=============================="
echo "Testing localhost HTTP (port 9000):"
kubectl exec $POD_NAME -c $AGENT_CONTAINER -n $NAMESPACE -- timeout 5 nc -zv localhost 9000 || echo "HTTP port 9000 not reachable"
echo
echo "Testing localhost gRPC (port 9500):"
kubectl exec $POD_NAME -c $AGENT_CONTAINER -n $NAMESPACE -- timeout 5 nc -zv localhost 9500 || echo "gRPC port 9500 not reachable"
echo

echo "6. Pod IP Connectivity Test"
echo "==========================="
POD_IP=$(kubectl get pod $POD_NAME -n $NAMESPACE -o jsonpath='{.status.podIP}')
echo "Pod IP: $POD_IP"
echo "Testing Pod IP HTTP (port 9000):"
kubectl exec $POD_NAME -c $AGENT_CONTAINER -n $NAMESPACE -- timeout 5 nc -zv $POD_IP 9000 || echo "Pod IP port 9000 not reachable"
echo
echo "Testing Pod IP gRPC (port 9500):"
kubectl exec $POD_NAME -c $AGENT_CONTAINER -n $NAMESPACE -- timeout 5 nc -zv $POD_IP 9500 || echo "Pod IP port 9500 not reachable"
echo

echo "7. iptables Rules Check (on node)"
echo "================================="
NODE_NAME=$(kubectl get pod $POD_NAME -n $NAMESPACE -o jsonpath='{.spec.nodeName}')
echo "Pod is running on node: $NODE_NAME"
echo "To check iptables rules on the node, run:"
echo "  ssh $NODE_NAME 'iptables -L -n -v | grep 127.0.0.1'"
echo "  ssh $NODE_NAME 'iptables -S | grep 127.0.0.1'"
echo

echo "8. K3s and Flannel Configuration"
echo "================================"
echo "Flannel pods in kube-system:"
kubectl get pods -n kube-system -l app=flannel
echo
echo "To check Flannel configuration:"
echo "  kubectl get configmap kube-flannel-cfg -n kube-system -o yaml"
echo

echo "9. Container Logs for Context"
echo "============================="
echo "Recent agent logs:"
kubectl logs $POD_NAME -c $AGENT_CONTAINER -n $NAMESPACE --tail=10
echo
echo "Recent server logs:"
kubectl logs $POD_NAME -c $SERVER_CONTAINER -n $NAMESPACE --tail=10
echo

echo "=== Diagnostic Complete ==="
echo
echo "Summary:"
echo "- If network namespaces are different, this indicates container isolation issue"
echo "- If Pod IP works but localhost doesn't, this indicates loopback interface restriction"
echo "- Check iptables rules on the node for localhost traffic blocking"
echo "- Consider Pod IP workaround as immediate solution"