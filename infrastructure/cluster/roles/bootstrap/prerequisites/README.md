# Platform Prerequisites Role

## Overview

This role installs and configures essential platform tools required for MLOps platform deployment. It ensures all critical dependencies are properly installed before any other platform components are deployed, preventing version conflicts and missing dependencies.

## Purpose

**Solves Critical Issues:**
- ✅ **yq Version Conflicts**: Ensures yq v4 (Go-based) is installed, preventing sealed secrets failures
- ✅ **Tool Consistency**: Standardizes tool versions across all platform deployments  
- ✅ **Dependency Management**: Installs all required tools before platform deployment
- ✅ **Version Verification**: Validates tool functionality before proceeding
- ✅ **SSH Connectivity**: Verifies SSH access to all cluster nodes before deployment

## Components Installed

### Critical Tools
- **yq v4** (Go-based YAML processor) - Required for sealed secrets
- **Helm v3** - Kubernetes package manager
- **kubectl** - Kubernetes CLI tool
- **jq** - JSON processor

### System Packages
- curl, wget, unzip, git, rsync, htop, net-tools

### Python Dependencies
- kubernetes, pyyaml, requests (for Ansible modules)

### SSH Connectivity Verification
- Tests SSH access to all cluster nodes
- Detects SSH key verification issues
- Provides fix commands for SSH problems
- Prevents Harbor containerd configuration failures

## Configuration

### Default Variables

```yaml
# Tool installation control
prerequisites_install_yq: true
prerequisites_yq_version: "v4.44.3"
prerequisites_yq_install_method: "binary"  # binary, snap, or package

prerequisites_install_helm: true
prerequisites_helm_version: "v3.15.4"

prerequisites_install_kubectl: true
prerequisites_kubectl_version: "latest"

# SSH connectivity verification
prerequisites_verify_ssh: true

# System packages
prerequisites_system_packages:
  - curl
  - wget
  - unzip
  - jq
  - git
  - rsync
  - htop
  - net-tools

# Cleanup conflicting packages
prerequisites_remove_conflicting_packages:
  - yq  # Remove apt/yum version that conflicts with v4
```

## Usage

### Automatic Deployment
The prerequisites role is automatically included as Phase 0 in both playbooks:

```bash
# Runs prerequisites automatically
ansible-playbook -i inventory/production/hosts infrastructure/cluster/site.yml
ansible-playbook -i inventory/production/hosts infrastructure/cluster/site-multiplatform.yml
```

### Manual Prerequisites Only
```bash
# Install just prerequisites
ansible-playbook -i inventory/production/hosts infrastructure/cluster/site.yml --tags prerequisites

# Force reinstall with specific yq method
ansible-playbook -i inventory/production/hosts infrastructure/cluster/site.yml --tags prerequisites -e prerequisites_yq_install_method=snap
```

## yq Installation Methods

### Binary Install (Recommended - Default)
- Downloads official yq v4 binary from GitHub releases
- Installs to `/usr/local/bin/yq` with symlink to `/usr/bin/yq`  
- Most reliable across different distributions
- Works in containers and restricted environments

### Snap Install (Alternative)
```yaml
prerequisites_yq_install_method: "snap"
```
- Uses snap package manager
- Good for Ubuntu/Debian systems with snap support
- May not be available in containers

## Problem Solved

### Before Prerequisites Role
```
❌ Harbor role installs yq via apt → Wrong version (Python-based v3)
❌ Sealed secrets fail with empty files
❌ Multiple roles installing conflicting tools
❌ Deployment fails unpredictably
```

### After Prerequisites Role  
```
✅ Prerequisites installs yq v4 (Go-based) correctly
✅ All sealed secrets work properly
✅ Single source of truth for tool versions
✅ Reliable, predictable deployments
```

## Tasks Breakdown

1. **Cleanup**: Remove conflicting package versions
2. **System Packages**: Install essential system tools
3. **yq Installation**: Install correct yq v4 with version verification
4. **Helm Installation**: Install Helm v3 package manager
5. **kubectl Installation**: Install Kubernetes CLI
6. **Python Dependencies**: Install Ansible module requirements  
7. **Verification**: Test all tools functionality
8. **Validation**: Fail if critical tools missing

## Verification Output

```
🔍 Platform Tools Verification Results:

✅ yq v4: value
✅ helm: v3.15.4+g5a5738d
✅ kubectl: v1.31.2
✅ jq: "value"

🎯 Platform Prerequisites: READY ✅
```

## Integration

### Platform Playbook Integration
This role runs as **Phase 0** in both playbooks:

**site.yml**:
```yaml
# PHASE 0: PLATFORM PREREQUISITES
- name: Install Platform Prerequisites
  hosts: localhost
  connection: local  
  gather_facts: false
  tasks:
    - include_role: name: foundation/prerequisites
```

**site-multiplatform.yml**:
- Same integration pattern
- Runs before platform detection
- Ensures tools available for all platforms

### Dependencies
- **No dependencies** - This is the foundational role
- **Runs first** - Before all other platform components
- **Self-contained** - Downloads tools directly from official sources

## Troubleshooting

### Common Issues

1. **Network Connectivity**
   - Tools downloaded from GitHub releases and official sources
   - Ensure internet access from deployment machine

2. **Permission Issues**  
   - Uses `become: true` for system-level installations
   - Ensure sudo access on deployment machine

3. **Tool Already Installed**
   - Role checks existing versions and skips if correct
   - Use `--tags prerequisites` to force reinstall

### Debug Commands

```bash
# Check tool versions
yq --version
helm version --short  
kubectl version --client --short
jq --version

# Manual tool tests
echo "test: value" | yq '.test'
echo '{"test": "value"}' | jq '.test'
helm repo list
```

## Best Practices

1. **Run Prerequisites First**: Always ensure prerequisites complete before platform deployment
2. **Version Pinning**: Pin tool versions in production for consistency  
3. **Verification**: Always check verification output for tool functionality
4. **Cleanup**: Role removes conflicting packages - review before deployment
5. **Documentation**: Update tool versions in documentation when updating defaults

## Security Considerations

- Downloads tools from official sources (GitHub releases, helm.sh)
- Verifies tool functionality before proceeding
- Uses system package managers where appropriate
- Creates temporary directories with appropriate permissions

## Platform Support

- **Ubuntu**: 20.04+, 22.04+ (tested)
- **Debian**: 11+, 12+ (tested)  
- **RHEL/CentOS**: 8+, 9+ (tested)
- **Container**: Works in containerized Ansible environments

---

**Role Version**: 1.0.0  
**Purpose**: Foundation platform prerequisites  
**Dependencies**: None  
**Maintained By**: Platform Team  
**Critical For**: Sealed secrets, Harbor replication, all Kubernetes operations