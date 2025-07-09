#!/bin/bash
set -e

# Deploy Custom Seldon Agent Script
# This script automates the process of deploying custom agent images via Docker Hub

AGENT_IMAGE="${1:-seldon-agent:2.9.0-pr6582-test}"
DOCKER_REPO="${2:-jtayl22/seldon-agent}"
TAG="${3:-2.9.0-pr6582-test}"

echo "🚀 Deploying custom Seldon agent: $AGENT_IMAGE"

# Step 1: Tag image for Docker Hub
echo "🏷️  Tagging image for Docker Hub..."
docker tag "$AGENT_IMAGE" "$DOCKER_REPO:$TAG"

# Step 2: Push to Docker Hub
echo "📤 Pushing to Docker Hub..."
docker push "$DOCKER_REPO:$TAG"

# Step 3: Apply configuration via Ansible
echo "🔧 Applying custom agent configuration via Ansible..."
ansible-playbook -i inventory/production/hosts infrastructure/cluster/site.yml --tags seldon --limit localhost

echo "✅ Custom agent deployment complete!"
echo ""
echo "🔍 To verify:"
echo "kubectl describe serverconfig mlserver -n seldon-system | grep Image"
echo "kubectl get pods -n seldon-system | grep mlserver"
echo ""
echo "📊 Check deployment:"
echo "kubectl logs -n seldon-system mlserver-0 -c agent"