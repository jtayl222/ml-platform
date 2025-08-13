#!/bin/bash
set -e

echo "🚀 Adding control plane node to existing kubeadm cluster..."
echo ""

# Parse arguments
NODE=""
while [[ $# -gt 0 ]]; do
  case $1 in
    --node)
      NODE="$2"
      shift 2
      ;;
    *)
      echo "Usage: $0 --node <hostname>"
      echo "Example: $0 --node nuc10i3-2"
      echo ""
      echo "Available control plane nodes from inventory:"
      grep -A 10 "\[kubeadm_control_plane\]" inventory/production/hosts-kubeadm | grep -v "^\[" | grep -v "^$" | awk '{print $1}'
      exit 1
      ;;
  esac
done

if [ -z "$NODE" ]; then
  echo "❌ Error: --node parameter is required"
  echo ""
  echo "Available control plane nodes from inventory:"
  grep -A 10 "\[kubeadm_control_plane\]" inventory/production/hosts-kubeadm | grep -v "^\[" | grep -v "^$" | awk '{print $1}'
  exit 1
fi

# Check prerequisites
command -v ansible-playbook >/dev/null 2>&1 || { echo "❌ Ansible required"; exit 1; }
command -v kubectl >/dev/null 2>&1 || { echo "❌ kubectl required"; exit 1; }

# Get the first control plane node
FIRST_CONTROL_PLANE=$(grep -A 10 "\[kubeadm_control_plane\]" inventory/production/hosts-kubeadm | grep -v "^\[" | grep -v "^$" | head -1 | awk '{print $1}')

echo "📋 Configuration:"
echo "   Target node: $NODE"
echo "   Primary control plane: $FIRST_CONTROL_PLANE"
echo ""

# Check if the node is already in the cluster
export KUBECONFIG=/home/user/REPOS/ml-platform/infrastructure/fetched_tokens/kubeconfig-kubeadm
if kubectl get nodes | grep -q "^$NODE "; then
  echo "⚠️  Node $NODE is already in the cluster"
  kubectl get nodes | grep "^$NODE "
  echo ""
  read -p "Do you want to remove and re-add it? (y/N): " -n 1 -r
  echo ""
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
  fi
  
  echo "🧹 Removing node from cluster..."
  kubectl drain $NODE --ignore-daemonsets --delete-emptydir-data --force || true
  kubectl delete node $NODE || true
  
  echo "🧹 Cleaning up node..."
  ansible $NODE -i inventory/production/hosts-kubeadm -m shell -a "sudo kubeadm reset --force" -b || true
  ansible $NODE -i inventory/production/hosts-kubeadm -m shell -a "sudo rm -rf /etc/kubernetes /var/lib/etcd /var/lib/kubelet" -b || true
fi

echo "🔑 Generating new join token..."
# Generate certificate key for control plane join
CERT_KEY=$(ansible $FIRST_CONTROL_PLANE -i inventory/production/hosts-kubeadm -m shell -a "sudo kubeadm init phase upload-certs --upload-certs 2>/dev/null | grep -v '\[upload-certs\]' | tail -1" -b | grep -v "CHANGED" | tail -1 | tr -d ' ')

if [ -z "$CERT_KEY" ]; then
  echo "❌ Failed to generate certificate key"
  exit 1
fi

echo "   Certificate key: ${CERT_KEY:0:20}..."

# Get join token
TOKEN=$(ansible $FIRST_CONTROL_PLANE -i inventory/production/hosts-kubeadm -m shell -a "sudo kubeadm token create" -b | grep -v "CHANGED" | tail -1)

if [ -z "$TOKEN" ]; then
  echo "❌ Failed to generate join token"
  exit 1
fi

echo "   Join token: ${TOKEN:0:20}..."

# Get discovery token CA cert hash
CA_CERT_HASH=$(ansible $FIRST_CONTROL_PLANE -i inventory/production/hosts-kubeadm -m shell -a "openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | openssl rsa -pubin -outform der 2>/dev/null | openssl dgst -sha256 -hex | sed 's/^.* //'" -b | grep -v "CHANGED" | tail -1)

if [ -z "$CA_CERT_HASH" ]; then
  echo "❌ Failed to get CA cert hash"
  exit 1
fi

echo "   CA cert hash: sha256:${CA_CERT_HASH:0:20}..."

# Get API server endpoint (just IP:port, no https://)
CONTROL_PLANE_IP=$(grep "^$FIRST_CONTROL_PLANE " inventory/production/hosts-kubeadm | awk '{print $2}' | sed 's/ansible_host=//')
if [ -z "$CONTROL_PLANE_IP" ]; then
  # Try to get from kubectl if available
  CONTROL_PLANE_IP=$(ansible $FIRST_CONTROL_PLANE -i inventory/production/hosts-kubeadm -m shell -a "kubectl config view --raw -o jsonpath='{.clusters[0].cluster.server}' 2>/dev/null | sed 's|https://||' | sed 's|:6443||'" -b | grep -v "CHANGED" | tail -1)
fi

API_SERVER="${CONTROL_PLANE_IP}:6443"

echo "   API server: $API_SERVER"
echo ""

echo "🔧 Ensuring prerequisites on $NODE..."
echo "   Stopping services..."
ansible $NODE -i inventory/production/hosts-kubeadm -m shell -a "sudo systemctl stop kubelet 2>/dev/null || true; sudo systemctl stop containerd 2>/dev/null || true" -b || true

echo "   Killing zombie processes..."
ansible $NODE -i inventory/production/hosts-kubeadm -m shell -a "sudo timeout 5 pkill -9 -f containerd-shim 2>/dev/null || true; sudo timeout 5 pkill -9 -f kubelet 2>/dev/null || true" -b || true

echo "   Cleaning directories..."
ansible $NODE -i inventory/production/hosts-kubeadm -m shell -a "sudo rm -rf /var/lib/containerd/* /run/containerd/* /var/lib/kubelet/* /etc/kubernetes/manifests/* 2>/dev/null || true" -b || true

echo "   Starting containerd..."
ansible $NODE -i inventory/production/hosts-kubeadm -m shell -a "sudo systemctl start containerd" -b || true

echo "   Waiting for containerd to be ready..."
sleep 5

echo "🚀 Joining $NODE as control plane..."
JOIN_CMD="sudo kubeadm join $API_SERVER --token $TOKEN --discovery-token-ca-cert-hash sha256:$CA_CERT_HASH --control-plane --certificate-key $CERT_KEY"

echo "   Running join command..."
ansible $NODE -i inventory/production/hosts-kubeadm -m shell -a "$JOIN_CMD" -b

echo ""
echo "⏳ Waiting for node to be ready..."
for i in {1..60}; do
  if kubectl get nodes | grep "^$NODE " | grep -q "Ready"; then
    echo "✅ Node $NODE successfully joined as control plane!"
    kubectl get nodes | grep "^$NODE "
    break
  fi
  echo -n "."
  sleep 5
done

echo ""
echo "📊 Cluster status:"
kubectl get nodes -o wide

echo ""
echo "🎉 Control plane node $NODE has been added successfully!"
echo ""
echo "💡 Next steps:"
echo "   1. Verify the node is functioning: kubectl get pods -n kube-system -o wide | grep $NODE"
echo "   2. Check etcd cluster health: kubectl exec -n kube-system etcd-$NODE -- etcdctl member list"
echo "   3. Update load balancer configuration if needed"