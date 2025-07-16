#!/bin/bash

# Test Harbor Integration with K3s

HARBOR_IP=${HARBOR_IP:-"192.168.1.210"}
HARBOR_USER=${HARBOR_USER:-"admin"}
HARBOR_PASSWORD=${HARBOR_PASSWORD:-"Harbor12345"}
KUBECONFIG=${KUBECONFIG:-"/tmp/k3s-kubeconfig.yaml"}

echo "🧪 Testing Harbor Integration with K3s"
echo "====================================="

# Test 1: Check if Harbor registry config exists on nodes
echo "1. Checking registry configuration on K3s nodes..."
ssh 192.168.1.85 "cat /etc/rancher/k3s/registries.yaml" 2>/dev/null
if [ $? -eq 0 ]; then
    echo "✅ Registry configuration found on control plane"
else
    echo "❌ Registry configuration missing on control plane"
fi

# Test 2: Check Harbor pull secrets
echo -e "\n2. Checking Harbor pull secrets in namespaces..."
kubectl --kubeconfig=$KUBECONFIG get secrets --all-namespaces | grep harbor-pull-secret

# Test 3: Test pulling an image through Harbor
echo -e "\n3. Testing image pull from Harbor..."
kubectl --kubeconfig=$KUBECONFIG run test-harbor \
    --image=$HARBOR_IP/library/nginx:latest \
    --restart=Never \
    --rm=true \
    -i \
    --timeout=60s \
    -- echo "Harbor test successful" 2>&1

# Test 4: Check if containerd can pull from Harbor
echo -e "\n4. Testing direct containerd pull..."
ssh 192.168.1.85 "sudo crictl pull $HARBOR_IP/library/nginx:latest" 2>&1

# Test 5: List images in Harbor
echo -e "\n5. Available images in Harbor:"
curl -s -u $HARBOR_USER:$HARBOR_PASSWORD http://$HARBOR_IP/api/v2.0/projects/library/repositories | jq -r '.[].name' 2>/dev/null || echo "No images found or unable to query Harbor API"

echo -e "\n✅ Harbor integration test completed!"
echo ""
echo "📝 To use Harbor in your deployments:"
echo "1. Push images: docker push $HARBOR_IP/library/myimage:tag"
echo "2. Use in K8s: image: $HARBOR_IP/library/myimage:tag"
echo "3. Or use Docker Hub mirror: image: myimage:tag (will pull through Harbor)"