#!/bin/bash
set -euo pipefail

# Infrastructure Role Migration Utility
# Safely migrates roles from current structure to new layered architecture

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CLUSTER_ROOT="$REPO_ROOT/infrastructure/cluster"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Migration phase tracking
MIGRATION_STATE_FILE="$REPO_ROOT/.migration_state"

get_migration_phase() {
    if [[ -f "$MIGRATION_STATE_FILE" ]]; then
        cat "$MIGRATION_STATE_FILE"
    else
        echo "0"
    fi
}

set_migration_phase() {
    echo "$1" > "$MIGRATION_STATE_FILE"
    log_success "Migration phase set to: $1"
}

# Role migration mappings
declare -A ROLE_MIGRATIONS=(
    # Bootstrap layer
    ["foundation/prerequisites"]="bootstrap/prerequisites"
    ["foundation/platform_detection"]="bootstrap/platform_detection"
    
    # Cluster layer
    ["foundation/k3s_control_plane"]="cluster/k3s"
    ["foundation/k3s_workers"]="cluster/k3s"
    ["foundation/kubeadm_cluster"]="cluster/kubeadm"
    ["foundation/eks_cluster"]="cluster/eks"
    ["foundation/fetch_kubeconfig"]="cluster/kubeconfig"
    ["foundation/cilium"]="cluster/cni/cilium"
    
    # Networking layer
    ["foundation/metallb"]="networking/metallb"
    ["foundation/coredns-test-domains"]="networking/test_domains"
    
    # Storage layer
    ["foundation/nfs_server"]="storage/nfs/server"
    ["foundation/nfs_clients"]="storage/nfs/clients"
    ["foundation/nfs_provisioner"]="storage/nfs/provisioner"
    ["storage/minio"]="storage/minio"
    ["storage/credentials"]="storage/credentials"
    
    # Security layer
    ["foundation/sealed_secrets"]="security/sealed_secrets"
    ["foundation/secrets"]="security/secrets"
    ["foundation/harbor-certs"]="security/certs/harbor"
    
    # Platform layer
    ["platform/argo_cd"]="platform/argo/cd"
    ["platform/argo_workflows"]="platform/argo/workflows" 
    ["platform/argo_events"]="platform/argo/events"
    ["platform/istio"]="platform/ingress/istio"
    ["platform/harbor"]="platform/registry/harbor"
    ["platform/dashboard"]="platform/dashboard"
    ["foundation/kafka"]="platform/data/kafka"
    
    # MLOps layer
    ["platform/seldon"]="mlops/seldon"
    ["mlops/mlflow"]="mlops/mlflow"
    ["mlops/kubeflow"]="mlops/kubeflow"
    ["mlops/kserve"]="mlops/kserve"
    
    # Observability layer
    ["monitoring/prometheus_stack"]="observability/prometheus_stack"
)

# Create new directory structure
create_directory_structure() {
    log_info "Creating new directory structure..."
    
    local new_dirs=(
        "roles/bootstrap"
        "roles/cluster/cni"
        "roles/networking" 
        "roles/storage/nfs"
        "roles/security/certs"
        "roles/platform/argo"
        "roles/platform/ingress"
        "roles/platform/registry"
        "roles/platform/data"
        "roles/mlops"
        "roles/observability"
        "playbooks"
        "inventories/dev"
        "inventories/staging" 
        "inventories/prod"
        "group_vars/all"
        "group_vars/k3s"
        "group_vars/kubeadm"
        "group_vars/eks"
        "utilities/kube_helpers"
        "utilities/scripts"
    )
    
    for dir in "${new_dirs[@]}"; do
        mkdir -p "$CLUSTER_ROOT/$dir"
    done
    
    log_success "Directory structure created"
}

# Backup existing roles
backup_existing_roles() {
    log_info "Creating backup of existing roles..."
    
    local backup_dir="$REPO_ROOT/backup-$(date +%Y%m%d-%H%M%S)"
    cp -r "$CLUSTER_ROOT/roles" "$backup_dir-roles"
    
    if [[ -f "$CLUSTER_ROOT/site.yml" ]]; then
        cp "$CLUSTER_ROOT/site.yml" "$backup_dir-site.yml"
    fi
    
    log_success "Backup created at: $backup_dir"
}

# Migrate a single role
migrate_role() {
    local old_path="$1"
    local new_path="$2"
    
    log_info "Migrating role: $old_path -> $new_path"
    
    local old_full_path="$CLUSTER_ROOT/roles/$old_path"
    local new_full_path="$CLUSTER_ROOT/roles/$new_path"
    
    if [[ ! -d "$old_full_path" ]]; then
        log_warning "Source role not found: $old_full_path"
        return 1
    fi
    
    # Create destination directory
    mkdir -p "$(dirname "$new_full_path")"
    
    # Special handling for k3s unification
    if [[ "$old_path" == "foundation/k3s_control_plane" || "$old_path" == "foundation/k3s_workers" ]]; then
        if [[ ! -d "$new_full_path" ]]; then
            # First k3s role - copy structure
            cp -r "$old_full_path" "$new_full_path"
            log_info "Created unified k3s role from: $old_path"
        else
            # Second k3s role - merge tasks
            log_info "Merging k3s tasks from: $old_path"
            # This requires manual intervention - create marker file
            touch "$new_full_path/.needs_manual_merge"
            echo "$old_path" >> "$new_full_path/.needs_manual_merge"
        fi
    else
        # Standard role migration
        if [[ -d "$new_full_path" ]]; then
            log_warning "Destination already exists: $new_full_path"
            return 1
        fi
        
        cp -r "$old_full_path" "$new_full_path"
    fi
    
    log_success "Migrated: $old_path -> $new_path"
}

# Update role references in files
update_role_references() {
    log_info "Updating role references in playbooks and meta files..."
    
    # Find all files that might contain role references
    local files_to_update=(
        $(find "$CLUSTER_ROOT" -name "*.yml" -o -name "*.yaml")
    )
    
    for file in "${files_to_update[@]}"; do
        if [[ -f "$file" ]]; then
            # Create backup of file
            cp "$file" "$file.backup"
            
            # Update role references
            for old_role in "${!ROLE_MIGRATIONS[@]}"; do
                local new_role="${ROLE_MIGRATIONS[$old_role]}"
                sed -i.tmp "s|name: $old_role|name: $new_role|g" "$file"
                sed -i.tmp "s|role: $old_role|role: $new_role|g" "$file"
            done
            
            rm -f "$file.tmp"
        fi
    done
    
    log_success "Role references updated"
}

# Create layered playbooks
create_layered_playbooks() {
    log_info "Creating layered playbooks..."
    
    # Bootstrap playbook
    cat > "$CLUSTER_ROOT/playbooks/bootstrap.yml" << 'EOF'
---
- name: Bootstrap Infrastructure Prerequisites
  hosts: all
  gather_facts: true
  become: true
  tags: [bootstrap]
  
  roles:
    - role: bootstrap/prerequisites
      tags: [prerequisites]
      
    - role: bootstrap/platform_detection
      tags: [platform_detection]
EOF

    # Cluster playbook  
    cat > "$CLUSTER_ROOT/playbooks/cluster.yml" << 'EOF'
---
- name: Deploy Kubernetes Cluster
  hosts: k8s_control_plane
  gather_facts: true
  become: true
  tags: [cluster, control_plane]
  
  roles:
    - role: cluster/{{ cluster_provider | default('k3s') }}
      node_role: "{{ 'server' if cluster_provider == 'k3s' else 'master' }}"
      
    - role: cluster/cni/{{ cni_provider | default('cilium') }}
      
    - role: cluster/kubeconfig

- name: Deploy Kubernetes Workers
  hosts: k8s_workers
  gather_facts: true  
  become: true
  tags: [cluster, workers]
  
  roles:
    - role: cluster/{{ cluster_provider | default('k3s') }}
      node_role: "{{ 'agent' if cluster_provider == 'k3s' else 'worker' }}"
EOF

    # Platform playbook
    cat > "$CLUSTER_ROOT/playbooks/platform.yml" << 'EOF'
---
- name: Deploy Platform Services
  hosts: localhost
  connection: local
  gather_facts: false
  tags: [platform]
  
  tasks:
    # Networking layer
    - name: Deploy networking components
      block:
        - include_role:
            name: networking/metallb
          tags: [networking, metallb]
          
    # Storage layer  
    - name: Deploy storage components
      block:
        - include_role:
            name: storage/nfs/server
          tags: [storage, nfs]
          
        - include_role:
            name: storage/minio
          tags: [storage, minio]
          
        - include_role:
            name: storage/credentials
          tags: [storage, credentials]
          
    # Security layer
    - name: Deploy security components
      block:
        - include_role:
            name: security/sealed_secrets
          tags: [security, sealed_secrets]
          
        - include_role:
            name: security/secrets
          tags: [security, secrets]
          
    # Platform services
    - name: Deploy platform services
      block:
        - include_role:
            name: platform/argo/cd
          tags: [platform, argo, gitops]
          
        - include_role:
            name: platform/ingress/{{ ingress_provider | default('istio') }}
          tags: [platform, ingress]
          
        - include_role:
            name: platform/registry/harbor
          when: enable_harbor | default(true)
          tags: [platform, registry]
          
        - include_role:
            name: platform/dashboard
          tags: [platform, dashboard]
EOF

    # MLOps playbook
    cat > "$CLUSTER_ROOT/playbooks/mlops.yml" << 'EOF'
---
- name: Deploy MLOps Services
  hosts: localhost
  connection: local
  gather_facts: false
  tags: [mlops]
  
  tasks:
    - name: Deploy MLOps components
      block:
        - include_role:
            name: mlops/mlflow
          tags: [mlops, mlflow]
          
        - include_role:
            name: mlops/seldon
          tags: [mlops, seldon, serving]
          
        - include_role:
            name: mlops/kserve
          when: enable_kserve | default(true)
          tags: [mlops, kserve, serving]
          
        - include_role:
            name: mlops/kubeflow
          when: enable_kubeflow | default(false)
          tags: [mlops, kubeflow, pipelines]
EOF

    # Observability playbook
    cat > "$CLUSTER_ROOT/playbooks/observability.yml" << 'EOF'
---
- name: Deploy Observability Stack
  hosts: localhost
  connection: local
  gather_facts: false
  tags: [observability]
  
  tasks:
    - name: Deploy observability components
      block:
        - include_role:
            name: observability/prometheus_stack
          tags: [observability, prometheus, monitoring]
EOF

    # New master playbook
    cat > "$CLUSTER_ROOT/playbooks/site.yml" << 'EOF'
---
# MLOps Platform - Layered Deployment
- import_playbook: bootstrap.yml
  tags: [bootstrap]

- import_playbook: cluster.yml  
  tags: [cluster]
  
- import_playbook: platform.yml
  tags: [platform]
  
- import_playbook: mlops.yml
  tags: [mlops]
  
- import_playbook: observability.yml
  tags: [observability]
EOF

    log_success "Layered playbooks created"
}

# Create environment inventories
create_environment_inventories() {
    log_info "Creating environment-specific inventories..."
    
    # Dev environment
    cat > "$CLUSTER_ROOT/inventories/dev/hosts" << 'EOF'
[k8s_control_plane]
dev-master ansible_host=192.168.1.85

[k8s_workers]  
dev-worker1 ansible_host=192.168.1.103
dev-worker2 ansible_host=192.168.1.104

[nfs_server]
dev-master

[all:vars]
ansible_user=k3s
ansible_ssh_private_key_file=~/.ssh/id_rsa
EOF

    cat > "$CLUSTER_ROOT/inventories/dev/group_vars/all.yml" << 'EOF'
---
# Development Environment Configuration
cluster_provider: k3s
cluster_name: dev-k8s
cni_provider: cilium
ingress_provider: istio
storage_provider: nfs

# Feature flags
enable_harbor: false
enable_kubeflow: false
enable_kserve: true
enable_monitoring: true
enable_mlflow: true

# Resource configuration
metallb_ip_range: "192.168.1.200-210"
metallb_state: present

# Development-specific settings
k3s_version: latest
k3s_server_args:
  - "--disable=traefik"
  - "--cluster-cidr=10.42.0.0/16"
  - "--service-cidr=10.43.0.0/16"
EOF

    # Staging environment
    mkdir -p "$CLUSTER_ROOT/inventories/staging"
    cp "$CLUSTER_ROOT/inventories/dev/hosts" "$CLUSTER_ROOT/inventories/staging/"
    cat > "$CLUSTER_ROOT/inventories/staging/group_vars/all.yml" << 'EOF'
---
# Staging Environment Configuration  
cluster_provider: k3s
cluster_name: staging-k8s
cni_provider: cilium
ingress_provider: istio
storage_provider: nfs

# Feature flags (more like production)
enable_harbor: true
enable_kubeflow: false
enable_kserve: true
enable_monitoring: true
enable_mlflow: true

# Resource configuration
metallb_ip_range: "192.168.1.220-230"
metallb_state: present

# Staging-specific settings
k3s_version: stable
EOF

    # Production environment
    mkdir -p "$CLUSTER_ROOT/inventories/prod"
    cat > "$CLUSTER_ROOT/inventories/prod/hosts" << 'EOF'
[k8s_control_plane]
prod-master1 ansible_host=192.168.1.85
prod-master2 ansible_host=192.168.1.86  
prod-master3 ansible_host=192.168.1.87

[k8s_workers]
prod-worker1 ansible_host=192.168.1.103
prod-worker2 ansible_host=192.168.1.104
prod-worker3 ansible_host=192.168.1.105
prod-worker4 ansible_host=192.168.1.107

[nfs_server]
prod-master1

[all:vars]
ansible_user=k3s
ansible_ssh_private_key_file=~/.ssh/id_rsa
EOF

    cat > "$CLUSTER_ROOT/inventories/prod/group_vars/all.yml" << 'EOF'
---
# Production Environment Configuration
cluster_provider: kubeadm
cluster_name: prod-k8s
cni_provider: calico
ingress_provider: istio
storage_provider: ceph

# Feature flags (full production)
enable_harbor: true
enable_kubeflow: true
enable_kserve: true
enable_monitoring: true
enable_mlflow: true
enable_ha: true

# Resource configuration
metallb_ip_range: "192.168.1.240-250"
metallb_state: present

# Production-specific settings
kubeadm_version: "1.30.4"
EOF

    log_success "Environment inventories created"
}

# Validate migration
validate_migration() {
    log_info "Validating migration..."
    
    local validation_errors=0
    
    # Check that all expected roles exist
    for new_role in "${ROLE_MIGRATIONS[@]}"; do
        local role_path="$CLUSTER_ROOT/roles/$new_role"
        if [[ ! -d "$role_path" ]]; then
            log_error "Missing migrated role: $new_role"
            ((validation_errors++))
        fi
    done
    
    # Check for roles that need manual intervention
    local manual_merge_roles=($(find "$CLUSTER_ROOT/roles" -name ".needs_manual_merge"))
    if [[ ${#manual_merge_roles[@]} -gt 0 ]]; then
        log_warning "The following roles need manual merging:"
        for role in "${manual_merge_roles[@]}"; do
            local role_dir="$(dirname "$role")"
            log_warning "  - $role_dir"
            cat "$role"
        done
    fi
    
    # Check playbook syntax
    local playbooks=($(find "$CLUSTER_ROOT/playbooks" -name "*.yml"))
    for playbook in "${playbooks[@]}"; do
        if ! ansible-playbook --syntax-check "$playbook" >/dev/null 2>&1; then
            log_error "Playbook syntax error: $playbook"
            ((validation_errors++))
        fi
    done
    
    if [[ $validation_errors -eq 0 ]]; then
        log_success "Migration validation passed"
        return 0
    else
        log_error "Migration validation failed with $validation_errors errors"
        return 1
    fi
}

# Main execution
main() {
    log_info "Starting infrastructure role migration..."
    
    local current_phase=$(get_migration_phase)
    log_info "Current migration phase: $current_phase"
    
    case "${1:-auto}" in
        "structure")
            create_directory_structure
            set_migration_phase 1
            ;;
        "backup")
            backup_existing_roles
            set_migration_phase 2
            ;;
        "migrate")
            log_info "Starting role migration..."
            for old_role in "${!ROLE_MIGRATIONS[@]}"; do
                migrate_role "$old_role" "${ROLE_MIGRATIONS[$old_role]}"
            done
            set_migration_phase 3
            ;;
        "playbooks")
            create_layered_playbooks
            create_environment_inventories
            set_migration_phase 4
            ;;
        "references")
            update_role_references
            set_migration_phase 5
            ;;
        "validate")
            validate_migration
            ;;
        "auto")
            # Full automated migration
            if [[ $current_phase -lt 1 ]]; then
                create_directory_structure
                set_migration_phase 1
            fi
            
            if [[ $current_phase -lt 2 ]]; then
                backup_existing_roles
                set_migration_phase 2
            fi
            
            if [[ $current_phase -lt 3 ]]; then
                log_info "Starting role migration..."
                for old_role in "${!ROLE_MIGRATIONS[@]}"; do
                    migrate_role "$old_role" "${ROLE_MIGRATIONS[$old_role]}" || true
                done
                set_migration_phase 3
            fi
            
            if [[ $current_phase -lt 4 ]]; then
                create_layered_playbooks
                create_environment_inventories
                set_migration_phase 4
            fi
            
            if [[ $current_phase -lt 5 ]]; then
                update_role_references
                set_migration_phase 5
            fi
            
            validate_migration
            
            log_success "Migration completed successfully!"
            log_info "Next steps:"
            log_info "1. Review roles that need manual merging (marked with .needs_manual_merge)"
            log_info "2. Test deployment with: ansible-playbook -i inventories/dev/hosts playbooks/site.yml --check"
            log_info "3. Update CI/CD pipelines to use new structure"
            ;;
        "help")
            echo "Usage: $0 [structure|backup|migrate|playbooks|references|validate|auto|help]"
            echo ""
            echo "Commands:"
            echo "  structure  - Create new directory structure"
            echo "  backup     - Backup existing roles"
            echo "  migrate    - Migrate roles to new structure"
            echo "  playbooks  - Create layered playbooks"
            echo "  references - Update role references" 
            echo "  validate   - Validate migration"
            echo "  auto       - Run complete migration (default)"
            echo "  help       - Show this help"
            ;;
        *)
            log_error "Unknown command: $1"
            log_info "Run '$0 help' for usage information"
            exit 1
            ;;
    esac
}

# Run main function
main "$@"