#!/bin/bash
set -euo pipefail

# Unified K3s Role Creation Script
# Merges k3s_control_plane and k3s_workers into a single, parameterized role

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CLUSTER_ROOT="$REPO_ROOT/infrastructure/cluster"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

create_unified_k3s_role() {
    log_info "Creating unified k3s role..."
    
    local k3s_role_path="$CLUSTER_ROOT/roles/cluster/k3s"
    local old_control_plane="$CLUSTER_ROOT/roles/foundation/k3s_control_plane"
    local old_workers="$CLUSTER_ROOT/roles/foundation/k3s_workers"
    
    # Create role structure
    mkdir -p "$k3s_role_path"/{tasks,templates,defaults,vars,handlers,meta,tests,files}
    
    # Create main task file with routing logic
    cat > "$k3s_role_path/tasks/main.yml" << 'EOF'
---
# Unified K3s Role - Routes to server or agent installation based on node_role

- name: Validate node_role parameter
  assert:
    that:
      - node_role is defined
      - node_role in ['server', 'agent']
    fail_msg: "node_role must be defined and set to 'server' or 'agent'"
  tags: [k3s, validation]

- name: Set k3s facts based on node role
  set_fact:
    is_k3s_server: "{{ node_role == 'server' }}"
    is_k3s_agent: "{{ node_role == 'agent' }}"
  tags: [k3s, facts]

- name: Debug k3s role configuration
  debug:
    msg:
      - "K3s Node Configuration:"
      - "  - Node Role: {{ node_role }}"
      - "  - Is Server: {{ is_k3s_server }}"
      - "  - Is Agent: {{ is_k3s_agent }}"
      - "  - K3s Version: {{ k3s_version | default('latest') }}"
  tags: [k3s, debug]

# Common tasks for both server and agent
- name: Execute common k3s tasks
  include_tasks: common.yml
  tags: [k3s, common]

# Server-specific tasks (control plane)
- name: Execute k3s server tasks
  include_tasks: server.yml
  when: is_k3s_server | bool
  tags: [k3s, server, control_plane]

# Agent-specific tasks (workers)
- name: Execute k3s agent tasks
  include_tasks: agent.yml
  when: is_k3s_agent | bool
  tags: [k3s, agent, workers]

# Post-installation validation
- name: Validate k3s installation
  include_tasks: validate.yml
  tags: [k3s, validate]
EOF

    # Create common tasks file
    cat > "$k3s_role_path/tasks/common.yml" << 'EOF'
---
# Common tasks for both K3s server and agent nodes

- name: Install required packages
  package:
    name: "{{ item }}"
    state: present
  loop: "{{ k3s_required_packages }}"
  become: true
  tags: [k3s, packages]

- name: Configure firewall for k3s
  include_tasks: firewall.yml
  when: configure_firewall | default(true)
  tags: [k3s, firewall]

- name: Create k3s user
  user:
    name: "{{ k3s_user }}"
    system: true
    shell: /usr/sbin/nologin
    home: /var/lib/rancher/k3s
    createhome: true
  become: true
  tags: [k3s, user]

- name: Create k3s directories
  file:
    path: "{{ item }}"
    state: directory
    owner: root
    group: root
    mode: '0755'
  loop:
    - /etc/rancher/k3s
    - /var/lib/rancher/k3s
  become: true
  tags: [k3s, directories]
EOF

    # Create server tasks file (from k3s_control_plane)
    if [[ -f "$old_control_plane/tasks/install.yml" ]]; then
        cp "$old_control_plane/tasks/install.yml" "$k3s_role_path/tasks/server.yml"
    else
        cat > "$k3s_role_path/tasks/server.yml" << 'EOF'
---
# K3s Server (Control Plane) Installation Tasks

- name: Check if k3s server is already installed
  stat:
    path: /usr/local/bin/k3s
  register: k3s_binary
  tags: [k3s, server, check]

- name: Download k3s binary
  get_url:
    url: "https://github.com/k3s-io/k3s/releases/download/{{ k3s_version }}/k3s"
    dest: /usr/local/bin/k3s
    mode: '0755'
    owner: root
    group: root
  become: true
  when: not k3s_binary.stat.exists or force_k3s_reinstall | default(false)
  tags: [k3s, server, install]

- name: Create k3s server configuration
  template:
    src: server-config.yaml.j2
    dest: /etc/rancher/k3s/config.yaml
    owner: root
    group: root
    mode: '0644'
  become: true
  notify: restart k3s
  tags: [k3s, server, config]

- name: Create k3s systemd service
  template:
    src: k3s-server.service.j2
    dest: /etc/systemd/system/k3s.service
    owner: root
    group: root
    mode: '0644'
  become: true
  notify:
    - reload systemd
    - restart k3s
  tags: [k3s, server, systemd]

- name: Start and enable k3s server
  systemd:
    name: k3s
    state: started
    enabled: true
    daemon_reload: true
  become: true
  tags: [k3s, server, service]

- name: Wait for k3s server to be ready
  wait_for:
    port: 6443
    host: "{{ ansible_default_ipv4.address }}"
    timeout: 300
  tags: [k3s, server, wait]

- name: Get k3s node token
  slurp:
    src: /var/lib/rancher/k3s/server/node-token
  register: k3s_token
  become: true
  tags: [k3s, server, token]

- name: Set k3s token fact for agents
  set_fact:
    k3s_node_token: "{{ k3s_token.content | b64decode | trim }}"
  tags: [k3s, server, token]
EOF
    fi

    # Create agent tasks file (from k3s_workers)
    if [[ -f "$old_workers/tasks/main.yml" ]]; then
        # Extract agent-specific tasks from workers main.yml
        grep -A 1000 "agent" "$old_workers/tasks/main.yml" > "$k3s_role_path/tasks/agent.yml" 2>/dev/null || \
        cat > "$k3s_role_path/tasks/agent.yml" << 'EOF'
---
# K3s Agent (Worker) Installation Tasks

- name: Check if k3s agent is already installed
  stat:
    path: /usr/local/bin/k3s
  register: k3s_binary
  tags: [k3s, agent, check]

- name: Download k3s binary
  get_url:
    url: "https://github.com/k3s-io/k3s/releases/download/{{ k3s_version }}/k3s"
    dest: /usr/local/bin/k3s
    mode: '0755'
    owner: root
    group: root
  become: true
  when: not k3s_binary.stat.exists or force_k3s_reinstall | default(false)
  tags: [k3s, agent, install]

- name: Create k3s agent configuration
  template:
    src: agent-config.yaml.j2
    dest: /etc/rancher/k3s/config.yaml
    owner: root
    group: root
    mode: '0644'
  become: true
  notify: restart k3s-agent
  tags: [k3s, agent, config]

- name: Create k3s agent systemd service
  template:
    src: k3s-agent.service.j2
    dest: /etc/systemd/system/k3s-agent.service
    owner: root
    group: root
    mode: '0644'
  become: true
  notify:
    - reload systemd
    - restart k3s-agent
  tags: [k3s, agent, systemd]

- name: Start and enable k3s agent
  systemd:
    name: k3s-agent
    state: started
    enabled: true
    daemon_reload: true
  become: true
  tags: [k3s, agent, service]
EOF
    else
        cat > "$k3s_role_path/tasks/agent.yml" << 'EOF'
---
# K3s Agent (Worker) Installation Tasks

- name: Verify k3s server token is available
  assert:
    that:
      - k3s_node_token is defined
      - k3s_server_url is defined
    fail_msg: "k3s_node_token and k3s_server_url must be defined for agent nodes"
  tags: [k3s, agent, validation]

- name: Check if k3s agent is already installed
  stat:
    path: /usr/local/bin/k3s
  register: k3s_binary
  tags: [k3s, agent, check]

- name: Download k3s binary
  get_url:
    url: "https://github.com/k3s-io/k3s/releases/download/{{ k3s_version }}/k3s"
    dest: /usr/local/bin/k3s
    mode: '0755'
    owner: root
    group: root
  become: true
  when: not k3s_binary.stat.exists or force_k3s_reinstall | default(false)
  tags: [k3s, agent, install]

- name: Create k3s agent configuration
  template:
    src: agent-config.yaml.j2
    dest: /etc/rancher/k3s/config.yaml
    owner: root
    group: root
    mode: '0644'
  become: true
  notify: restart k3s-agent
  tags: [k3s, agent, config]

- name: Create k3s agent systemd service
  template:
    src: k3s-agent.service.j2
    dest: /etc/systemd/system/k3s-agent.service
    owner: root
    group: root
    mode: '0644'
  become: true
  notify:
    - reload systemd
    - restart k3s-agent
  tags: [k3s, agent, systemd]

- name: Start and enable k3s agent
  systemd:
    name: k3s-agent
    state: started
    enabled: true
    daemon_reload: true
  become: true
  tags: [k3s, agent, service]
EOF
    fi

    # Create firewall tasks
    cat > "$k3s_role_path/tasks/firewall.yml" << 'EOF'
---
# K3s Firewall Configuration

- name: Configure UFW for k3s
  block:
    - name: Allow k3s server API
      ufw:
        rule: allow
        port: "6443"
        proto: tcp
        comment: "k3s API server"
      when: is_k3s_server | bool

    - name: Allow kubelet API
      ufw:
        rule: allow
        port: "10250"
        proto: tcp
        comment: "kubelet API"

    - name: Allow k3s server metrics
      ufw:
        rule: allow
        port: "10251"
        proto: tcp
        comment: "k3s server metrics"
      when: is_k3s_server | bool

    - name: Allow flannel VXLAN
      ufw:
        rule: allow
        port: "8472"
        proto: udp
        comment: "flannel VXLAN"
      when: cni_provider | default('flannel') == 'flannel'

  become: true
  when: ansible_os_family == "Debian"
  tags: [k3s, firewall, ufw]

- name: Configure firewalld for k3s
  block:
    - name: Open k3s ports in firewalld
      firewalld:
        port: "{{ item }}"
        permanent: true
        state: enabled
        immediate: true
      loop:
        - "6443/tcp"  # k3s API
        - "10250/tcp" # kubelet API
        - "8472/udp"  # flannel VXLAN

  become: true
  when: ansible_os_family == "RedHat"
  tags: [k3s, firewall, firewalld]
EOF

    # Create validation tasks
    cat > "$k3s_role_path/tasks/validate.yml" << 'EOF'
---
# K3s Installation Validation

- name: Check k3s service status
  systemd:
    name: "{{ 'k3s' if is_k3s_server else 'k3s-agent' }}"
  register: k3s_service_status
  tags: [k3s, validate, service]

- name: Verify k3s binary is executable
  stat:
    path: /usr/local/bin/k3s
  register: k3s_binary_stat
  failed_when: not k3s_binary_stat.stat.exists or not k3s_binary_stat.stat.executable
  tags: [k3s, validate, binary]

- name: Check k3s version
  command: /usr/local/bin/k3s --version
  register: k3s_version_output
  changed_when: false
  tags: [k3s, validate, version]

- name: Validate k3s server (control plane only)
  block:
    - name: Check if kubectl works
      command: /usr/local/bin/k3s kubectl get nodes
      register: kubectl_nodes
      changed_when: false

    - name: Verify server node is ready
      command: /usr/local/bin/k3s kubectl wait --for=condition=Ready node/{{ ansible_hostname }} --timeout=300s
      changed_when: false

  when: is_k3s_server | bool
  tags: [k3s, validate, server]

- name: Display k3s status
  debug:
    msg:
      - "K3s {{ node_role }} installation completed:"
      - "  - Service Status: {{ k3s_service_status.status.ActiveState }}"
      - "  - Version: {{ k3s_version_output.stdout }}"
      - "  - Binary: {{ k3s_binary_stat.stat.path }}"
  tags: [k3s, validate, status]
EOF

    # Merge defaults from both old roles
    cat > "$k3s_role_path/defaults/main.yml" << 'EOF'
---
# Unified K3s Role Defaults

# K3s version and installation
k3s_version: "v1.30.4+k3s1"
k3s_user: "k3s"

# Node role (REQUIRED): server or agent
# node_role: server|agent  # Must be set when calling role

# Network configuration
cluster_cidr: "10.42.0.0/16"
service_cidr: "10.43.0.0/16"
cluster_dns: "10.43.0.10"

# CNI configuration
cni_provider: "cilium"  # cilium, flannel, calico
disable_default_cni: "{{ cni_provider != 'flannel' }}"

# Server configuration
k3s_server_args:
  - "--disable=traefik"
  - "--cluster-cidr={{ cluster_cidr }}"
  - "--service-cidr={{ service_cidr }}"
  - "--cluster-dns={{ cluster_dns }}"
  - "{{ '--flannel-backend=none' if disable_default_cni else '' }}"

# Agent configuration  
k3s_agent_args: []

# Server URL for agents (set automatically by server)
k3s_server_url: "https://{{ groups['k3s_control_plane'][0] }}:6443"

# Token for joining (set automatically by server)
k3s_node_token: ""

# System configuration
configure_firewall: true
force_k3s_reinstall: false

# Required packages
k3s_required_packages:
  - curl
  - wget

# Registry configuration
k3s_registries_config: {}

# Feature gates
k3s_feature_gates: {}

# Data directory
k3s_data_dir: "/var/lib/rancher/k3s"
EOF

    # Create handlers
    cat > "$k3s_role_path/handlers/main.yml" << 'EOF'
---
# K3s Handlers

- name: reload systemd
  systemd:
    daemon_reload: true
  become: true

- name: restart k3s
  systemd:
    name: k3s
    state: restarted
  become: true
  when: is_k3s_server | default(false)

- name: restart k3s-agent
  systemd:
    name: k3s-agent
    state: restarted
  become: true
  when: is_k3s_agent | default(false)
EOF

    # Create meta dependencies
    cat > "$k3s_role_path/meta/main.yml" << 'EOF'
---
# K3s Role Dependencies

galaxy_info:
  author: MLOps Platform Team
  description: Unified K3s installation role for servers and agents
  license: MIT
  min_ansible_version: 2.9
  platforms:
    - name: Ubuntu
      versions:
        - focal
        - jammy
    - name: Debian
      versions:
        - bullseye
        - bookworm
    - name: EL
      versions:
        - 8
        - 9

dependencies:
  - role: bootstrap/prerequisites
    when: run_prerequisites | default(true)

collections:
  - kubernetes.core
  - ansible.posix
EOF

    # Create systemd service templates
    mkdir -p "$k3s_role_path/templates"
    
    cat > "$k3s_role_path/templates/k3s-server.service.j2" << 'EOF'
[Unit]
Description=Lightweight Kubernetes
Documentation=https://k3s.io
Wants=network-online.target
After=network-online.target
ConditionFileIsExecutable=/usr/local/bin/k3s

[Service]
Type=notify
EnvironmentFile=-/etc/default/%N
EnvironmentFile=-/etc/sysconfig/%N
KillMode=process
Delegate=yes
LimitNOFILE=1048576
LimitNPROC=infinity
LimitCORE=infinity
TasksMax=infinity
TimeoutStartSec=0
Restart=always
RestartSec=5s
ExecStartPre=/bin/sh -xc '! /usr/bin/systemctl is-enabled --quiet nm-cloud-setup.service 2>/dev/null'
ExecStartPre=-/sbin/modprobe br_netfilter
ExecStartPre=-/sbin/modprobe overlay
ExecStart=/usr/local/bin/k3s server {{ k3s_server_args | join(' ') }}

[Install]
WantedBy=multi-user.target
EOF

    cat > "$k3s_role_path/templates/k3s-agent.service.j2" << 'EOF'
[Unit]
Description=Lightweight Kubernetes
Documentation=https://k3s.io
Wants=network-online.target
After=network-online.target
ConditionFileIsExecutable=/usr/local/bin/k3s

[Service]
Type=notify
EnvironmentFile=-/etc/default/%N
EnvironmentFile=-/etc/sysconfig/%N
KillMode=process
Delegate=yes
LimitNOFILE=1048576
LimitNPROC=infinity
LimitCORE=infinity
TasksMax=infinity
TimeoutStartSec=0
Restart=always
RestartSec=5s
ExecStartPre=-/sbin/modprobe br_netfilter
ExecStartPre=-/sbin/modprobe overlay
ExecStart=/usr/local/bin/k3s agent {{ k3s_agent_args | join(' ') }}

[Install]
WantedBy=multi-user.target
EOF

    cat > "$k3s_role_path/templates/server-config.yaml.j2" << 'EOF'
# K3s Server Configuration
{% if k3s_data_dir %}
data-dir: {{ k3s_data_dir }}
{% endif %}
{% if cluster_cidr %}
cluster-cidr: {{ cluster_cidr }}
{% endif %}
{% if service_cidr %}
service-cidr: {{ service_cidr }}
{% endif %}
{% if cluster_dns %}
cluster-dns: {{ cluster_dns }}
{% endif %}
{% if disable_default_cni %}
flannel-backend: none
{% endif %}
{% if k3s_registries_config %}
# Registry configuration
{% for registry, config in k3s_registries_config.items() %}
{{ registry }}:
{{ config | to_nice_yaml | indent(2, first=False) }}
{% endfor %}
{% endif %}
EOF

    cat > "$k3s_role_path/templates/agent-config.yaml.j2" << 'EOF'
# K3s Agent Configuration
server: {{ k3s_server_url }}
token: {{ k3s_node_token }}
{% if k3s_data_dir %}
data-dir: {{ k3s_data_dir }}
{% endif %}
{% if k3s_registries_config %}
# Registry configuration
{% for registry, config in k3s_registries_config.items() %}
{{ registry }}:
{{ config | to_nice_yaml | indent(2, first=False) }}
{% endfor %}
{% endif %}
EOF

    # Create README
    cat > "$k3s_role_path/README.md" << 'EOF'
# Unified K3s Role

This role installs and configures K3s on both server (control plane) and agent (worker) nodes using a single, parameterized role.

## Requirements

- Ansible 2.9+
- Target systems running Ubuntu 20.04+, Debian 11+, or RHEL/CentOS 8+

## Role Variables

### Required Variables

- `node_role`: Must be set to either `server` or `agent`

### Optional Variables

- `k3s_version`: K3s version to install (default: `v1.30.4+k3s1`)
- `cni_provider`: CNI to use (`cilium`, `flannel`, `calico`) (default: `cilium`)
- `cluster_cidr`: Pod CIDR range (default: `10.42.0.0/16`)
- `service_cidr`: Service CIDR range (default: `10.43.0.0/16`)
- `configure_firewall`: Whether to configure firewall rules (default: `true`)

## Dependencies

- `bootstrap/prerequisites`

## Example Playbook

```yaml
# Deploy K3s server (control plane)
- hosts: k3s_control_plane
  roles:
    - role: cluster/k3s
      node_role: server

# Deploy K3s agents (workers)  
- hosts: k3s_workers
  roles:
    - role: cluster/k3s
      node_role: agent
```

## Tags

- `k3s` - All k3s tasks
- `k3s,server` - Server-specific tasks
- `k3s,agent` - Agent-specific tasks
- `k3s,common` - Common tasks for both
- `k3s,validate` - Validation tasks

## Migration Notes

This role replaces the separate `foundation/k3s_control_plane` and `foundation/k3s_workers` roles. The functionality is preserved but unified under a single role with the `node_role` parameter controlling behavior.
EOF

    log_success "Unified k3s role created successfully"
    log_info "Role location: $k3s_role_path"
    log_warning "Review and test the unified role before using in production"
}

# Main execution
main() {
    log_info "Starting unified k3s role creation..."
    
    case "${1:-create}" in
        "create")
            create_unified_k3s_role
            log_success "Unified k3s role creation completed!"
            log_info "Next steps:"
            log_info "1. Review the generated role in roles/cluster/k3s/"
            log_info "2. Test with: ansible-playbook -i inventory playbook.yml --tags k3s --check"
            log_info "3. Update playbooks to use the new unified role"
            ;;
        "help")
            echo "Usage: $0 [create|help]"
            echo ""
            echo "Commands:"
            echo "  create - Create unified k3s role (default)"
            echo "  help   - Show this help"
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