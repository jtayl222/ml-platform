# Harbor Standalone Registry Integration

This Ansible role configures Kubernetes cluster nodes to access a standalone Harbor registry deployed outside the cluster.

## Overview

The `harbor_standalone` role handles:
- Containerd configuration for insecure registry access
- Docker daemon configuration for registry authentication
- Kubernetes secret creation for image pull authentication
- Registry certificate management (if using HTTPS)

## Requirements

- Standalone Harbor instance running (e.g., at `192.168.1.100`)
- Harbor accessible from all cluster nodes
- Admin credentials for Harbor registry

## Role Variables

```yaml
# Registry connection settings
harbor_standalone_registry: "192.168.1.100"
harbor_standalone_protocol: "http"
harbor_standalone_user: "admin"
harbor_standalone_password: "Harbor12345"

# Containerd configuration paths
containerd_certs_path: "/etc/containerd/certs.d"
containerd_config_path: "/etc/containerd"

# Kubernetes namespaces for registry secrets
harbor_namespaces:
  - default
  - mlflow
  - jupyterhub
  - seldon-system
  - financial-ml

# Enable automatic secret creation
harbor_create_secrets: true
```

## Harbor Server Management

### Starting Harbor After Reboot

Harbor installed via Docker Compose requires manual start after system reboot:

```bash
# SSH to Harbor server
ssh user@192.168.1.100

# Navigate to Harbor directory
cd /opt/harbor  # or /srv/harbor

# Start Harbor services
sudo docker compose up -d

# Verify all containers are running
sudo docker compose ps
```

### Enable Auto-start Service

Create systemd service for automatic startup:

```bash
# Create service file
sudo tee /etc/systemd/system/harbor.service > /dev/null <<EOF
[Unit]
Description=Harbor Container Registry
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/harbor
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF

# Enable and start
sudo systemctl daemon-reload
sudo systemctl enable harbor.service
sudo systemctl start harbor.service

# Check status
sudo systemctl status harbor.service
```

### Harbor Service Commands

```bash
# Start Harbor
sudo docker compose up -d

# Stop Harbor
sudo docker compose down

# Restart Harbor
sudo docker compose restart

# View logs
sudo docker compose logs -f

# Check container status
sudo docker compose ps

# Stop and remove volumes (CAUTION: deletes data)
sudo docker compose down -v
```

## Usage

### Deploy Role

```bash
# Deploy harbor_standalone configuration
ansible-playbook -i inventory/production/hosts infrastructure/cluster/site.yml --tags harbor-standalone

# Or with specific variables
ansible-playbook -i inventory/production/hosts infrastructure/cluster/site.yml \
  --tags harbor-standalone \
  -e harbor_standalone_registry=192.168.1.100 \
  -e harbor_standalone_password=MySecurePassword
```

### Test Registry Access

```bash
# From cluster node
docker login 192.168.1.100 -u admin -p Harbor12345
docker pull 192.168.1.100/library/nginx:latest

# From pod
kubectl run test --image=192.168.1.100/library/nginx:latest
```

## Integration with Platform Services

The role automatically configures registry access for:

- **MLflow**: Custom ML model images
- **JupyterHub**: Data science notebook images  
- **Seldon Core**: Model server images
- **MinIO**: Management client images

Images are referenced in service configurations:
```yaml
mlflow_image: "{{ harbor_standalone_registry }}/library/mlflow-postgresql:3.1.0-4"
jupyterhub_image_name: "{{ harbor_standalone_registry }}/library/financial-predictor-jupyter"
```

## Troubleshooting

### Common Issues

1. **Image pull failures**
   ```bash
   # Check containerd configuration
   cat /etc/containerd/certs.d/192.168.1.100/hosts.toml
   
   # Restart containerd
   sudo systemctl restart containerd
   ```

2. **Harbor not accessible**
   ```bash
   # Test connectivity
   curl http://192.168.1.100/api/v2.0/systeminfo
   
   # Check Harbor logs
   ssh user@192.168.1.100
   cd /opt/harbor
   sudo docker compose logs -f
   ```

3. **Authentication failures**
   ```bash
   # Verify secret in namespace
   kubectl get secret harbor-registry-secret -n default -o yaml
   
   # Re-create secret
   kubectl delete secret harbor-registry-secret -n default
   ansible-playbook -i inventory/production/hosts infrastructure/cluster/site.yml --tags harbor-standalone
   ```

## Files

- `defaults/main.yml` - Default variables
- `tasks/main.yml` - Main tasks for configuration
- `templates/containerd-config.toml.j2` - Containerd configuration template
- `templates/hosts.toml.j2` - Registry hosts configuration
- `handlers/main.yml` - Service restart handlers

## Dependencies

None, but typically deployed alongside:
- `foundation/k3s_control_plane` or `foundation/kubeadm_control_plane`
- `foundation/k3s_workers` or `foundation/kubeadm_workers`

## License

Same as main project

## Author

Platform Engineering Team