## User Acceptance Testing (UAT) Guide: MLOps Platform (for Customer Deployment)

**Document Version:** 2.0 (Revised)
**Date:** July 9, 2025
**Prepared For:** Customer's Platform/DevOps Team & ML Engineers

---

### 1. Introduction

This document outlines the User Acceptance Testing (UAT) strategy for the MLOps Platform repository. The primary goal of this UAT is to ensure that the customer can successfully deploy, configure, operate, and utilize the MLOps platform to support their machine learning workloads in an on-premise environment.

The `financial-mlops-pytorch` project will be used as a **reference application** to validate the platform's functionality and adherence to industry best practices. It serves as a realistic workload to test the platform's core services (Kubernetes, Argo Workflows, MLflow, Seldon Core, MinIO, etc.).

### 2. Platform Overview

This MLOps Platform provides a comprehensive, Kubernetes-native environment for the entire machine learning lifecycle. It is designed for on-premise deployment and emphasizes Infrastructure as Code (IaC), automation, security, and scalability.

*   **Core Components:** K3s (Kubernetes), Cilium (CNI), MetalLB (Load Balancer), MLflow (Experiment Tracking & Model Registry), Seldon Core (Model Serving), Argo Workflows (ML Pipelines), Argo CD (GitOps), JupyterHub (Development Environment), MinIO (Object Storage), Prometheus/Grafana (Monitoring).
*   **Automation:** Ansible playbooks for declarative infrastructure deployment and configuration.
*   **Security:** Integrated Sealed Secrets for secure credential management and network policies for workload isolation.
*   **Reference Application:** The `financial-mlops-pytorch` project will be used to demonstrate the platform's capability to host and execute real-world ML workflows.

### 3. Prerequisites for UAT

Before commencing UAT, ensure the following:

*   **Hardware:** Sufficient on-premise compute, memory, and storage resources as per platform requirements.
*   **Network:** Configured network environment (IP ranges, firewall rules) compatible with K3s, Cilium, and MetalLB.
*   **Base OS:** Supported Linux distribution on all target nodes.
*   **Access:** SSH access to all target nodes from the Ansible control machine.
*   **Tools:** `ansible`, `kubectl`, `argo`, `docker` (on control machine and target nodes as required).
*   **Repository Access:** Cloned `ml-platform` repository and `financial-mlops-pytorch` repository.

### 4. UAT Scenarios / Test Cases (for `ml-platform` repository)

The UAT will follow the typical lifecycle of deploying and operating the platform, using `financial-mlops-pytorch` to validate core functionality.

**Scenario 1: Initial Platform Deployment**

*   **Objective:** Verify successful, repeatable deployment of the entire MLOps platform from scratch.
*   **Steps:**
    1.  Prepare a clean set of target machines (VMs or bare metal).
    2.  Configure `inventory/production/hosts` with the target node details.
    3.  Execute initial setup scripts (e.g., `scripts/bootstrap.sh` if applicable for OS-level dependencies).
    4.  Run the main Ansible playbook: `ansible-playbook -i inventory/production/hosts infrastructure/cluster/site.yml`
*   **Expected Outcomes:**
    *   All Kubernetes nodes are `Ready` (`kubectl get nodes`).
    *   All core platform components (K3s, Cilium, MetalLB, MLflow, Seldon, Argo Workflows, MinIO, Prometheus, Grafana) are deployed and their pods are `Running` in their respective namespaces (`kubectl get pods -A`).
    *   Platform UIs (MLflow, Argo Workflows, Grafana, MinIO Console) are accessible via their configured IPs/NodePorts/LoadBalancer IPs.
    *   MetalLB LoadBalancer IPs are correctly assigned and accessible.

**Scenario 2: Platform Configuration & Customization**

*   **Objective:** Verify that key platform parameters can be customized by the customer.
*   **Steps:**
    1.  Modify `inventory/production/hosts` (e.g., change node IPs, add/remove nodes).
    2.  Modify `inventory/production/group_vars/all.yml` (e.g., adjust K3s CIDR ranges, change MinIO storage size, update MLflow database settings).
    3.  Re-run the main Ansible playbook: `ansible-playbook -i inventory/production/hosts infrastructure/cluster/site.yml`
*   **Expected Outcomes:**
    *   Platform components reflect the new configurations without errors.
    *   Existing workloads (if any) continue to function or are gracefully restarted.

**Scenario 3: Platform Operational Validation (using `financial-mlops-pytorch` as a workload)**

*   **Objective:** Verify the platform's ability to support a realistic ML workload, demonstrating its core MLOps capabilities.
*   **Steps (following `financial-mlops-pytorch`'s Quick Start):**
    1.  **Build & Push Application Images:** Build `financial-predictor` and `financial-predictor-jupyter` images and push them to the platform's configured Docker registry.
    2.  **Deploy Application Resources:** Apply `financial-mlops-pytorch`'s Kubernetes manifests (`kubectl apply -k k8s/base`, `kubectl apply -k k8s/manifests/...`).
    3.  **Run Data Pipeline:** Submit `financial-mlops-pytorch`'s data pipeline Argo Workflow.
    4.  **Run Model Training:** Submit `financial-mlops-pytorch`'s model training Argo Workflows (e.g., `baseline`, `enhanced` variants).
    5.  **Verify MLflow Tracking:** Confirm experiments, metrics, and artifacts are logged in the platform's MLflow UI.
    6.  **Verify Model Deployment:** Check that `financial-mlops-pytorch` models are deployed in the platform's Seldon Core.
    7.  **Test Model Inference:** Send inference requests to the deployed models and verify responses.
*   **Expected Outcomes:**
    *   All `financial-mlops-pytorch` pods are `Running` or `Completed`.
    *   Argo Workflows for data and training complete successfully.
    *   MLflow UI shows all expected experiments and runs.
    *   Seldon Core successfully serves the models, and inference requests return correct predictions.
    *   All interactions with platform components (MLflow, Argo, Seldon, MinIO) are successful, validating the platform's core functionality.

**Scenario 4: Platform Monitoring & Logging**

*   **Objective:** Verify that platform health and application logs are accessible for operational insights.
*   **Steps:**
    1.  Access the Grafana UI and review the pre-configured dashboards.
    2.  Access Prometheus to verify metrics collection from platform components.
    3.  Use `kubectl logs` to retrieve logs from various platform components (e.g., `mlflow-server`, `seldon-controller-manager`, `cilium-agent`).
    4.  Use `kubectl logs` to retrieve logs from `financial-mlops-pytorch` application pods.
    5.  (Optional) Use `scripts/parse-ansible-execution.py` to analyze Ansible deployment logs for deeper insights.
*   **Expected Outcomes:**
    *   Grafana dashboards display relevant metrics and health indicators.
    *   Prometheus is collecting metrics from all expected targets.
    *   Logs are accessible, readable, and provide useful diagnostic information for both platform and application components.

**Scenario 5: Secret Management Validation**

*   **Objective:** Verify the process for generating and applying secrets for new ML projects.
*   **Steps:**
    1.  Use `scripts/generate-ml-secrets.sh` to generate secrets for a *new* hypothetical ML project.
    2.  Apply the generated sealed secrets to a new namespace.
    3.  Deploy a simple test application that consumes these secrets.
*   **Expected Outcomes:**
    *   Secrets are generated correctly.
    *   The test application successfully consumes the secrets.

**Scenario 6: Platform Teardown & Re-deployment**

*   **Objective:** Verify the ability to cleanly remove and re-deploy the platform.
*   **Steps:**
    1.  Execute the K3s teardown script: `scripts/delete_k3s.sh` (or the equivalent Ansible playbook for teardown).
    2.  Verify all K3s components are removed.
    3.  Re-run the main Ansible playbook: `ansible-playbook -i inventory/production/hosts infrastructure/cluster/site.yml` for a fresh deployment.
*   **Expected Outcomes:**
    *   The platform is cleanly removed from the nodes.
    *   The platform is successfully re-deployed, returning to the state verified in Scenario 1.

### 5. Expected Outcomes / Verification Steps (General)

For all scenarios, successful completion implies:

*   All `ansible-playbook` and `kubectl` commands execute without errors.
*   All Kubernetes pods are in a `Running` or `Completed` state.
*   All services are accessible and responsive.
*   Logs are clean and do not show critical errors.
*   The platform behaves as documented and expected.

### 6. Feedback Mechanism

Please report any issues, bugs, or observations during UAT using the designated feedback mechanism (e.g., a shared issue tracker, email, or communication channel). For each issue, provide:

*   **Scenario Number:** (e.g., Scenario 3)
*   **Steps to Reproduce:** Detailed steps taken.
*   **Actual Outcome:** What happened.
*   **Expected Outcome:** What should have happened.
*   **Screenshots/Logs:** Attach relevant screenshots or log snippets.
*   **Severity:** (e.g., Critical, High, Medium, Low)

---