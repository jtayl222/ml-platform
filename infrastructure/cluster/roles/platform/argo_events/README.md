# Argo Events Ansible Role

This Ansible role manages the installation and configuration of [Argo Events](https://argoproj.github.io/argo-events/) in a Kubernetes cluster.

## Features

- Installs Argo Events via Helm (CRDs included)
- Ensures the `argo-events` namespace exists (if not present)
- Applies shared EventSource and Sensor manifests from the infrastructure repo
- Supports templated EventSource and Sensor definitions

## Directory Structure

```
tasks/
  main.yml
  eventsource.yml
  sensor.yml
templates/
  eventsource.yml.j2
  sensor.yml.j2
defaults/
  main.yml
```

## Usage

Include this role in your playbook:

```yaml
- hosts: localhost
  roles:
    - role: platform/argo_events
      vars:
        kubeconfig_path: ~/.kube/config
```

## Variables

See `defaults/main.yml` for configurable variables such as:

- `argo_events_namespace`
- `eventsource_name`, `eventsource_type`, `eventsource_config`
- `sensor_name`, `sensor_dependencies`, `sensor_triggers`

## Managing Shared EventSources and Sensors

To enable event-driven workflows (e.g., trigger workflows from Prometheus alerts, webhooks, S3, etc.), place your YAML manifests in:

- `infrastructure/manifests/argo-events/eventsources/`
- `infrastructure/manifests/argo-events/sensors/`

Then rerun your playbook with:

```sh
ansible-playbook -i inventory/production/hosts infrastructure/cluster/site.yml --tags=argo-events
```

This will apply all manifests in those directories.

## Example

To deploy a custom EventSource or Sensor, override the relevant variables or provide manifests in the directories above.

## References

- [Argo Events Documentation](https://argoproj.github.io/argo-events/)
- [Argo Events GitHub](https://github.com/argoproj/argo-events)