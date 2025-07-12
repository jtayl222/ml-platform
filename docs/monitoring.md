# Monitoring

This document provides an overview of the monitoring stack and critical considerations for data persistence.

## 1. Overview of the Monitoring Stack

Our MLOps platform leverages the [kube-prometheus-stack](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack) for comprehensive monitoring and alerting. This stack includes:

*   **Prometheus:** The core time-series database and monitoring system.
*   **Grafana:** For data visualization and dashboarding.
*   **Alertmanager:** For handling alerts sent by Prometheus.
*   **Node Exporter:** For collecting host-level metrics.
*   **kube-state-metrics:** For collecting Kubernetes object metrics.

## 2. Prometheus Data Persistence and Rebuilds

Understanding how Prometheus stores its data and how to preserve it across cluster rebuilds is crucial for maintaining historical metrics.

### 2.1. Where Prometheus Stores Its Data

Prometheus (along with Grafana and Alertmanager) is configured to store its data in **Persistent Volumes (PVs)**. These PVs are dynamically provisioned through **Persistent Volume Claims (PVCs)** using the `nfs-shared` StorageClass.

This means:
*   The data is not stored directly on the K3s cluster nodes themselves.
*   It resides on an **external NFS server** (typically in the `/srv/nfs/kubernetes/` directory on the NFS server, with subdirectories for each PV).

### 2.2. Data Survival During K3s Teardown (`scripts/delete_k3s.sh`)

Previously, the `scripts/delete_k3s.sh` script explicitly wiped the underlying NFS data. However, this has been changed.

**Current Behavior:**
*   When `scripts/delete_k3s.sh` is executed, it uninstalls the K3s cluster, which includes the deletion of Kubernetes objects like PVCs.
*   However, the script **no longer explicitly deletes the underlying NFS data** on the NFS server. This means the data will remain on the NFS share even after the K3s cluster is gone.

**Important Note:** While the NFS data itself will survive, the Kubernetes PVC and PV objects that link Prometheus to that data will be deleted when K3s is torn down. This leads to the next point on preservation.

### 2.3. Preserving Prometheus Data Across Rebuilds

To ensure Prometheus data is preserved and can be re-used after a K3s cluster rebuild, you need to manage the Persistent Volume lifecycle explicitly.

**The Challenge:** By default, dynamically provisioned PVs often have a `persistentVolumeReclaimPolicy` set to `Delete`. If this policy is active, when the Prometheus PVC is deleted (during K3s teardown), the associated PV and its underlying data on the NFS share are also automatically deleted.

**Recommended Strategy: Change PV Reclaim Policy to `Retain`**

This strategy ensures the underlying NFS data is not deleted when the PVC is removed, allowing it to be re-attached to a new Prometheus deployment.

1.  **Before K3s Teardown:**
    *   Identify the name of the PersistentVolume (PV) that Prometheus is currently using. You can find this by running `kubectl get pvc -n monitoring prometheus-kube-prometheus-stack-prometheus-db-prometheus-kube-prometheus-stack-prometheus-0` (the exact PVC name might vary slightly) and looking at the `VOLUME` column.
    *   Change the `persistentVolumeReclaimPolicy` of this PV from `Delete` to `Retain`:
        ```bash
        kubectl patch pv <prometheus-pv-name> -p '{"spec":{"persistentVolumeReclaimPolicy":"Retain"}}'
        ```
    *   Repeat this for Grafana and Alertmanager PVs if you wish to preserve their data as well.

2.  **Run `scripts/delete_k3s.sh`:**
    *   The K3s cluster will be torn down, and the Prometheus PVCs will be deleted. However, the PVs (and their data on NFS) will remain due to the `Retain` policy.

3.  **Rebuild K3s:**
    *   Deploy the new K3s cluster using your Ansible playbooks.

4.  **Recreate Prometheus Deployment to Bind to Existing PVs:**
    *   After the new K3s cluster is up, you will need to configure the Prometheus Helm chart (or manually create PVCs) to explicitly bind to the *existing* PVs that hold your historical data.
    *   This typically involves setting `volumeName` in the PVC spec to the name of the retained PV, or using specific labels/selectors to match the PV.
    *   When Prometheus is redeployed, it will then use the existing data from the NFS share.

### 2.4. Robust Data Protection (Beyond Rebuilds)

For true production resilience and disaster recovery, consider implementing a robust backup and restore strategy for your NFS share. This protects against data loss due to hardware failures, accidental deletions, or other unforeseen events, independent of Kubernetes cluster operations.

## 3. Accessing Monitoring Dashboards

*   **Grafana Dashboard:** `http://<K3S_CONTROL_PLANE_IP>:<GRAFANA_NODEPORT>` (default: `30300`)
*   **Prometheus UI:** `http://<K3S_CONTROL_PLANE_IP>:<PROMETHEUS_NODEPORT>` (default: `30090`)
*   **Pushgateway:** `http://<K3S_CONTROL_PLANE_IP>:<PUSHGATEWAY_NODEPORT>` (default: `32091`)

**Default Grafana Credentials:** `admin` / `admin123` (It is highly recommended to change this password immediately after deployment).