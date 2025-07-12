# Technical Debt Document

This document outlines known technical debt within the MLOps Platform. Technical debt represents design or implementation choices that prioritize short-term gains over long-term maintainability, scalability, or robustness. Documenting these items helps in transparent communication, risk management, and prioritization of future development efforts.

---

## 1. MinIO Data Persistence Across Cluster Rebuilds

*   **Problem Statement:** MinIO data (including MLflow models and artifacts) is not automatically preserved across K3s cluster rebuilds.
    *   When MinIO is deployed via Helm, its PersistentVolumeClaim (PVC) typically creates a PersistentVolume (PV) with a default `persistentVolumeReclaimPolicy` of `Delete`.
    *   During a K3s cluster teardown (e.g., using `scripts/delete_k3s.sh`), the MinIO PVC is deleted, which, by default, also triggers the deletion of the associated PV and its underlying data on the NFS share.

*   **Impact:**
    *   **Data Loss:** Risk of losing all MinIO data (MLflow models, artifacts, etc.) if the cluster is rebuilt without manual intervention.
    *   **Manual Intervention:** Requires manual steps to change the PV reclaim policy before teardown to preserve data.
    *   **Increased Operational Burden:** Adds complexity to cluster lifecycle management (teardown, rebuild, upgrade).

*   **Current Mitigation:**
    *   Manual change of the MinIO PV's `persistentVolumeReclaimPolicy` to `Retain` *before* executing `scripts/delete_k3s.sh`.
    *   Manual re-attachment of the retained PV to the new MinIO deployment after cluster rebuild.

*   **Proposed Solutions / Future Work:**
    *   **1. Automate PV Reclaim Policy Configuration:** Modify the MinIO Ansible role to programmatically set the `persistentVolumeReclaimPolicy` to `Retain` during initial deployment, or provide an option to do so.
    *   **2. Implement Robust Backup & Restore Solution:** Integrate a comprehensive backup and restore solution for the NFS share. This could involve:
        *   NFS server-side snapshots.
        *   A Kubernetes-native backup tool like [Velero](https://velero.io/) (requires a compatible storage provider).
    *   **3. Evaluate Alternative Storage Solutions:** Explore other persistent storage solutions for Kubernetes that offer more integrated and automated data lifecycle management (e.g., Rook-Ceph, Longhorn) if NFS proves to be a bottleneck or too complex for this use case.

*   **Priority:** High (due to potential data loss and operational impact).

---

## 2. Automated Infrastructure Testing and CI/CD

*   **Problem Statement:** While individual Ansible roles may have basic tests, there appears to be a lack of a comprehensive, automated Continuous Integration/Continuous Delivery (CI/CD) pipeline for the infrastructure code itself. This includes automated linting, syntax checks, and integration tests for the entire platform deployment.
*   **Impact:**
    *   **Reduced Confidence:** Lower confidence in infrastructure changes, potentially leading to manual verification and longer deployment cycles.
    *   **Increased Risk of Errors:** Errors in Ansible playbooks or Kubernetes manifests may only be caught during manual deployment, leading to downtime or unexpected behavior.
    *   **Slower Iteration:** Inhibits rapid and reliable iteration on the platform's infrastructure.
*   **Current Mitigation:** Manual execution of Ansible playbooks and visual inspection of deployed components.
*   **Proposed Solutions / Future Work:**
    *   Implement a CI pipeline (e.g., using GitHub Actions, GitLab CI, Jenkins) to:
        *   Run Ansible linting (`ansible-lint`).
        *   Perform Ansible syntax checks (`ansible-playbook --syntax-check`).
        *   Execute integration tests that deploy a minimal cluster and validate core components.
    *   Explore GitOps tools (beyond Argo CD for applications) for infrastructure changes to ensure desired state reconciliation.
*   **Priority:** High (Crucial for reliable and scalable infrastructure management).

---

## 3. Default Passwords and Initial Credential Management

*   **Problem Statement:** Several components are deployed with default administrative passwords (e.g., Grafana `admin123`, MinIO `minioadmin123`). While these are documented as needing overrides, relying on manual changes introduces a security risk if not addressed immediately post-deployment.
*   **Impact:**
    *   **Security Vulnerability:** Default credentials are a significant security risk, especially in production environments.
    *   **Operational Overhead:** Requires manual intervention to change passwords after initial deployment.
*   **Current Mitigation:** Documentation advises overriding default passwords in `group_vars`. Sealed Secrets are used for secure storage of *overridden* credentials.
*   **Proposed Solutions / Future Work:**
    *   **Enforce Secure Defaults:** Implement mechanisms to enforce the use of strong, non-default passwords during initial deployment (e.g., requiring them as Ansible extra-vars, or generating random ones if not provided).
    *   **Automated Secret Rotation:** Explore solutions for automated rotation of credentials.
    *   **Just-in-Time Access:** Implement principles of least privilege and just-in-time access for administrative interfaces.
*   **Priority:** High (Direct security implication).

---

## 4. Obsolete and Draft Documentation

*   **Problem Statement:** The `docs/` directory contains several files that appear to be either obsolete migration guides (`flannel-to-calico-migration-required.md`, `cni-migration-calico-to-cilium.md`) or unfinished draft articles (`ARTICLE_OUTLINE.md`, `ARTICLE.md`, `ARTICLE_NEW.md`, `CLAUDE.md`).
*   **Impact:**
    *   **Information Overload:** Can confuse users trying to find current and relevant documentation.
    *   **Inaccurate Information:** Obsolete guides might contain outdated instructions or architectural details.
    *   **Perceived Lack of Polish:** Suggests a lack of maintenance or attention to detail in documentation.
*   **Current Mitigation:** None, these files are present in the repository.
*   **Proposed Solutions / Future Work:**
    *   **Review and Curate:** Review all `docs/articles/` and old migration guides.
    *   **Archive/Remove:** Archive or remove content that is no longer relevant or intended for publication.
    *   **Complete/Integrate:** Complete draft articles and integrate them into the main documentation if they provide value.
    *   **Documentation Standards:** Establish clear guidelines for documentation lifecycle (drafting, publishing, archiving).
*   **Priority:** Medium (Primarily affects user experience and documentation quality).

---