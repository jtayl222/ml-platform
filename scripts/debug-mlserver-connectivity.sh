#!/bin/bash
# Debug MLServer connectivity issue

POD_NAME="mlserver-0"
NAMESPACE="financial-ml"

echo "=== MLServer Connectivity Debug ==="
echo

echo "1. Pod IP and Status"
echo "==================="
kubectl get pod $POD_NAME -n $NAMESPACE -o wide
POD_IP=$(kubectl get pod $POD_NAME -n $NAMESPACE -o jsonpath='{.status.podIP}')
echo "Pod IP: $POD_IP"
echo

echo "2. MLServer Process and Port Binding"
echo "===================================="
echo "Processes in MLServer container:"
kubectl exec $POD_NAME -c mlserver -n $NAMESPACE -- ps aux
echo
echo "Ports bound by MLServer:"
kubectl exec $POD_NAME -c mlserver -n $NAMESPACE -- netstat -tlpn 2>/dev/null || kubectl exec $POD_NAME -c mlserver -n $NAMESPACE -- ss -tlpn
echo

echo "3. MLServer Configuration"
echo "========================="
echo "MLServer environment variables:"
kubectl exec $POD_NAME -c mlserver -n $NAMESPACE -- env | grep -i mlserver
echo
echo "MLServer settings (if available):"
kubectl exec $POD_NAME -c mlserver -n $NAMESPACE -- find /opt -name "settings.json" -exec cat {} \; 2>/dev/null || echo "No settings.json found"
echo

echo "4. Container Network Interfaces"
echo "==============================="
echo "MLServer container interfaces:"
kubectl exec $POD_NAME -c mlserver -n $NAMESPACE -- ip addr
echo
echo "Agent container interfaces:"
kubectl exec $POD_NAME -c agent -n $NAMESPACE -- ip addr
echo

echo "5. Connectivity Tests"
echo "===================="
echo "HTTP connectivity test (port 9000):"
kubectl exec $POD_NAME -c agent -n $NAMESPACE -- timeout 5 nc -zv $POD_IP 9000 || echo "HTTP connection failed"
echo
echo "gRPC connectivity test (port 9500):"
kubectl exec $POD_NAME -c agent -n $NAMESPACE -- timeout 5 nc -zv $POD_IP 9500 || echo "gRPC connection failed"
echo
echo "HTTP health check:"
kubectl exec $POD_NAME -c agent -n $NAMESPACE -- timeout 5 curl -s http://$POD_IP:9000/v2/health 2>/dev/null || echo "HTTP health check failed"
echo

echo "6. Recent Container Logs"
echo "======================="
echo "MLServer logs (last 20 lines):"
kubectl logs $POD_NAME -c mlserver -n $NAMESPACE --tail=20
echo
echo "Agent logs (last 20 lines):"
kubectl logs $POD_NAME -c agent -n $NAMESPACE --tail=20
echo

echo "7. Pod Events"
echo "============"
kubectl describe pod $POD_NAME -n $NAMESPACE | grep -A20 Events
echo

echo "=== Debug Complete ==="
echo
echo "Analysis:"
echo "- If MLServer process is running but no ports are bound, it's a configuration issue"
echo "- If ports are bound but connection fails, it's a networking issue"
echo "- If HTTP works but gRPC doesn't, it's a protocol-specific issue"