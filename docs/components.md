# MLOps Platform Components

This document provides an overview of the main components deployed in this MLOps platform environment.

---

## Core Components

### 1. **Kubernetes (K3s)**
- Lightweight Kubernetes distribution used as the cluster orchestrator.
- Manages all workloads, networking, and persistent storage.

### 2. **MLflow**
- Open-source platform for managing the ML lifecycle, including experiment tracking, model registry, and artifact storage.
- Deployed with authentication enabled and PostgreSQL as the backend.

### 3. **PostgreSQL**
- Centralized relational database for MLflow tracking and authentication data.
- Deployed as a managed service or via a Helm chart.

### 4. **MinIO or S3-Compatible Storage**
- Object storage for MLflow artifacts (models, datasets, etc.).
- Can be MinIO (self-hosted) or an external S3-compatible service.

### 5. **Bitnami Sealed Secrets**
- Securely manages sensitive information (credentials, keys) in Kubernetes.
- Allows secrets to be safely stored in version control.

---

## Supporting Components

### 6. **NFS or CSI Storage**
- Provides persistent volumes for MLflow and other stateful workloads.

### 7. **Ingress Controller (optional)**
- Manages external access to services (e.g., MLflow UI/API) via HTTP/S.

### 8. **Ansible**
- Automates the deployment and configuration of all components.
- Ensures reproducibility and declarative infrastructure management.

---

## Security & Configuration

- **Secrets**: All sensitive data is managed via Sealed Secrets and injected as environment variables.
- **ConfigMaps**: Used for non-sensitive configuration, such as MLflow authentication config.
- **Custom Docker Images**: MLflow and other services are built with required dependencies for production use.

---

## Example Component Relationships

[User/Client] | [Ingress (optional)] | [Kubernetes Services] | [MLflow UI/API] <--> [PostgreSQL] | [MinIO/S3] (for artifacts)

---

## References

- [MLflow](https://mlflow.org/)
- [K3s](https://k3s.io/)
- [Bitnami Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets)
- [MinIO](https://min.io/)
-