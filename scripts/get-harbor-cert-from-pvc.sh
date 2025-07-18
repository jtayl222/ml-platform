#!/bin/bash
# Get Harbor certificate from PVC for external clients
# This script helps external clients (dev machines, CI/CD) get the latest Harbor certificate

set -euo pipefail

# Configuration
HARBOR_DOMAIN="harbor.test"
CERT_NAMESPACE="harbor-certs"
PVC_NAME="harbor-certs-pvc"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Function to extract certificate from PVC
extract_cert_from_pvc() {
    log "Extracting Harbor certificate from PVC..."
    
    # Create temporary pod to access PVC
    kubectl run cert-extractor \
        --image=alpine:latest \
        --restart=Never \
        --rm -i \
        --overrides='
    {
        "spec": {
            "containers": [
                {
                    "name": "cert-extractor",
                    "image": "alpine:latest",
                    "command": ["cat", "/persistent-certs/harbor-ca.crt"],
                    "volumeMounts": [
                        {
                            "name": "harbor-certs",
                            "mountPath": "/persistent-certs"
                        }
                    ]
                }
            ],
            "volumes": [
                {
                    "name": "harbor-certs",
                    "persistentVolumeClaim": {
                        "claimName": "'$PVC_NAME'"
                    }
                }
            ]
        }
    }' \
        --namespace="$CERT_NAMESPACE"
}

# Function to install certificate for Docker
install_docker_cert() {
    local cert_content="$1"
    
    log "Installing Harbor certificate for Docker..."
    
    # Create Docker cert directory
    sudo mkdir -p "/etc/docker/certs.d/$HARBOR_DOMAIN"
    
    # Install certificate
    echo "$cert_content" | sudo tee "/etc/docker/certs.d/$HARBOR_DOMAIN/ca.crt" > /dev/null
    
    # Set permissions
    sudo chmod 644 "/etc/docker/certs.d/$HARBOR_DOMAIN/ca.crt"
    
    log "Docker certificate installed ✅"
}

# Function to install certificate for containerd
install_containerd_cert() {
    local cert_content="$1"
    
    log "Installing Harbor certificate for containerd..."
    
    # Create containerd cert directory
    sudo mkdir -p "/etc/containerd/certs.d/$HARBOR_DOMAIN"
    
    # Install certificate
    echo "$cert_content" | sudo tee "/etc/containerd/certs.d/$HARBOR_DOMAIN/ca.crt" > /dev/null
    
    # Create hosts.toml
    sudo tee "/etc/containerd/certs.d/$HARBOR_DOMAIN/hosts.toml" > /dev/null <<EOF
server = "https://$HARBOR_DOMAIN"

[host."https://$HARBOR_DOMAIN"]
  capabilities = ["pull", "resolve"]
  ca = "/etc/containerd/certs.d/$HARBOR_DOMAIN/ca.crt"
  skip_verify = false
EOF
    
    # Set permissions
    sudo chmod 644 "/etc/containerd/certs.d/$HARBOR_DOMAIN/ca.crt"
    sudo chmod 644 "/etc/containerd/certs.d/$HARBOR_DOMAIN/hosts.toml"
    
    log "Containerd certificate installed ✅"
}

# Function to test Harbor access
test_harbor_access() {
    log "Testing Harbor access..."
    
    # Test Docker login
    if docker login "$HARBOR_DOMAIN" -u admin -p Harbor12345 --password-stdin <<< "Harbor12345" 2>/dev/null; then
        log "Docker login successful ✅"
    else
        warn "Docker login failed - check certificate installation"
    fi
    
    # Test Harbor API
    if curl -s -k "https://$HARBOR_DOMAIN/api/v2.0/systeminfo" > /dev/null; then
        log "Harbor API access successful ✅"
    else
        warn "Harbor API access failed"
    fi
}

# Main function
main() {
    local action="${1:-install}"
    
    case "$action" in
        "install")
            log "Installing Harbor certificate from PVC..."
            
            # Check if PVC exists
            if ! kubectl get pvc "$PVC_NAME" -n "$CERT_NAMESPACE" &>/dev/null; then
                error "Harbor certificate PVC not found: $PVC_NAME"
                error "Run: kubectl apply -f harbor-cert-pvc.yaml"
                exit 1
            fi
            
            # Extract certificate
            local cert_content
            cert_content=$(extract_cert_from_pvc)
            
            if [[ -z "$cert_content" ]]; then
                error "Failed to extract certificate from PVC"
                exit 1
            fi
            
            # Install for Docker
            install_docker_cert "$cert_content"
            
            # Install for containerd
            install_containerd_cert "$cert_content"
            
            # Test access
            test_harbor_access
            
            log "Harbor certificate installation completed! 🚀"
            ;;
            
        "show")
            log "Showing Harbor certificate from PVC..."
            extract_cert_from_pvc
            ;;
            
        "verify")
            log "Verifying Harbor certificate installation..."
            test_harbor_access
            ;;
            
        *)
            echo "Usage: $0 [install|show|verify]"
            echo "  install  - Install Harbor certificate from PVC (default)"
            echo "  show     - Show certificate content from PVC"
            echo "  verify   - Verify Harbor access with installed certificate"
            exit 1
            ;;
    esac
}

# Run main function
main "$@"