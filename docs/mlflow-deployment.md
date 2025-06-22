# MLflow Deployment Guide

This document describes how MLflow is deployed in this homelab, with a focus on secure authentication, secret management, and production readiness.

---

## Overview

- **MLflow** is deployed on Kubernetes using a custom Docker image.
- **Authentication** is enabled using MLflow's experimental basic-auth app.
- **All secrets** (database credentials, admin credentials, Flask secret key, S3 keys) are managed using [Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets).
- **Configuration** is injected at runtime using environment variables and a templated INI file.

---

## Secret Management

### Sealed Secrets

All sensitive credentials are stored as Kubernetes Sealed Secrets, including:
- MLflow tracking admin username and password
- MLflow PostgreSQL database username and password
- Flask server secret key (for CSRF/session security)
- S3 access keys (for artifact storage)

Sealed secrets are created using scripts like:

```bash
./scripts/create-sealed-secret.sh mlflow-basic-auth mlflow \
  MLFLOW_TRACKING_USERNAME="mlflow" \
  MLFLOW_TRACKING_PASSWORD="mlflow123" \
  MLFLOW_FLASK_SERVER_SECRET_KEY="(random 32-byte string)"

./scripts/create-sealed-secret.sh mlflow-db-credentials mlflow \
  username="mlflow" \
  password="mlflow-secure-password-123"
```

These secrets are referenced in the MLflow deployment as environment variables.

---

## Authentication Configuration

### Auth ConfigMap

MLflow's authentication system requires an INI-format config file. This is provided via a Kubernetes ConfigMap, with placeholders for secrets:

```ini
[mlflow]
database_uri = postgresql+psycopg2://${MLFLOW_DB_USERNAME}:${MLFLOW_DB_PASSWORD}@<db_host>:<db_port>/<auth_db_name>
default_permission = READ
admin_username = ${MLFLOW_TRACKING_USERNAME}
admin_password = ${MLFLOW_TRACKING_PASSWORD}
authorization_function = mlflow.server.auth:authenticate_request_basic_auth
```

This file is mounted into the container at `/tmp/auth_config.ini`.

---

### Runtime Variable Substitution

At container startup, the following happens:

1. **envsubst** replaces placeholders in `/tmp/auth_config.ini` with actual environment variable values, creating `/tmp/auth_config_resolved.ini`.
2. The environment variable `MLFLOW_AUTH_CONFIG_PATH` is set to `/tmp/auth_config_resolved.ini`.
3. MLflow is started with the `--app-name basic-auth` flag and all required backend arguments.

Example startup command:

```bash
envsubst < /tmp/auth_config.ini > /tmp/auth_config_resolved.ini
export MLFLOW_AUTH_CONFIG_PATH=/tmp/auth_config_resolved.ini
mlflow server \
  --backend-store-uri "postgresql://$MLFLOW_DB_USERNAME:$MLFLOW_DB_PASSWORD@<db_host>:<db_port>/<db_name>" \
  --registry-store-uri "postgresql://$MLFLOW_DB_USERNAME:$MLFLOW_DB_PASSWORD@<db_host>:<db_port>/<db_name>" \
  --default-artifact-root "s3://<bucket>/" \
  --serve-artifacts \
  --host "0.0.0.0" \
  --port "5000" \
  --app-name basic-auth
```

---

## Why This Approach?

- **Security:** No secrets are stored in plaintext in the repo or ConfigMaps.
- **Flexibility:** Credentials can be rotated without changing manifests.
- **Production-Ready:** Uses PostgreSQL for both tracking and authentication, avoiding SQLite limitations.
- **Maintainability:** All configuration is declarative and managed via Ansible and Kubernetes manifests.

---

## Troubleshooting

- If authentication fails, check that all environment variables are correctly set in the pod.
- If MLflow fails to start, check the logs for database connection errors or config file parsing errors.
- Ensure the Docker image includes `gettext` (for `envsubst`) and `mlflow[auth]` dependencies.

---

You have exceeded your premium request allowance. We have automatically switched you to GPT-4.1 which is included with your plan. [Enable additional paid premium requests](command:chat.enablePremiumOverages) to continue using premium models.These changes were necessary to enable **secure, production-ready authentication for MLflow** using sealed secrets and a centralized PostgreSQL database for both tracking and authentication, in line with MLflow’s latest best practices.

### Here’s why each change was needed:

---

#### **1. Sealed Secrets for Credentials**
- **Why:**  
  Storing sensitive credentials (DB username/password, MLflow admin user/password, Flask secret key) in plaintext or in ConfigMaps is insecure.
- **What changed:**  
  The playbook now applies sealed secrets for:
  - S3 credentials
  - MLflow basic auth credentials
  - MLflow DB credentials

---

#### **2. Auth Config as a ConfigMap (INI, not YAML)**
- **Why:**  
  MLflow’s authentication system expects an INI-format config file, not YAML.  
  The config must reference environment variables, not hardcoded secrets, for security and flexibility.
- **What changed:**  
  The ConfigMap now provides `auth_config.ini` with `${VARIABLE}` placeholders, which are resolved at runtime.

---

#### **3. Runtime Variable Substitution with `envsubst`**
- **Why:**  
  Kubernetes mounts the ConfigMap as a file with placeholders.  
  These must be replaced with actual secret values from the environment before MLflow starts.
- **What changed:**  
  The container’s startup command now runs `envsubst` to generate a resolved config file with real credentials.

---

#### **4. Environment Variables from Sealed Secrets**
- **Why:**  
  MLflow and the auth config both need access to the same secrets, but securely.
- **What changed:**  
  The deployment mounts all necessary secrets as environment variables, which are then used by both MLflow and the config file.

---

#### **5. Correct MLflow Server Startup**
- **Why:**  
  MLflow’s `--app-name basic-auth` enables authentication, but it also needs the correct config and secrets.
- **What changed:**  
  The startup command now:
  - Resolves the config file
  - Sets the `MLFLOW_AUTH_CONFIG_PATH`
  - Starts MLflow with all required arguments

---

#### **6. Volume Mounts for ConfigMap**
- **Why:**  
  The config file must be available in the container filesystem for MLflow to read.
- **What changed:**  
  The deployment mounts the ConfigMap at `/tmp/auth_config.ini`.

---

#### **7. PostgreSQL for Auth and Tracking**
- **Why:**  
  Using PostgreSQL for both tracking and authentication is required for multi-node, production deployments and avoids SQLite limitations.
- **What changed:**  
  The config and server args now use PostgreSQL URIs for both tracking and auth.

---

### **Summary of Recent Changes (June 22, 2025)**

| Change                                 | Why?                                      | What it enables/fixes                  |
|-----------------------------------------|-------------------------------------------|----------------------------------------|
| Sealed secrets for all credentials      | Security, GitOps best practice            | No plaintext secrets in manifests      |
| INI config with env vars                | MLflow auth expects INI, not YAML         | Correct config parsing                 |
| `envsubst` at startup                  | Dynamic secret injection                  | Secure, flexible config at runtime     |
| All secrets as env vars                 | Secure, dynamic secret management         | No hardcoded secrets                   |
| Correct MLflow startup command          | Auth, config, and secrets all required    | MLflow starts with authentication      |
| ConfigMap volume mount                  | File must exist in container              | MLflow can read config                 |
| PostgreSQL for auth/tracking            | Production, multi-node, reliability       | No SQLite, no split state              |

---

**In short:**  
These changes were necessary to securely enable MLflow authentication, use sealed secrets for all sensitive data, ensure the config is in the correct format, and make the deployment production-ready and maintainable.
---

## References

- [MLflow Authentication Docs](https://www.mlflow.org/docs/latest/ml/auth/index.html)
- [Bitnami Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets)
- [MLflow Docker Deployment](https://www.mlflow.org/docs/latest/cli.html#mlflow-server)