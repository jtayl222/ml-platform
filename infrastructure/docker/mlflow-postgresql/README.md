# MLflow with PostgreSQL Support

Custom MLflow Docker image with PostgreSQL driver pre-installed.

## 🏗️ **Build Information**
- **Base Image**: `ghcr.io/mlflow/mlflow:v2.17.2`
- **Added Dependencies**: `psycopg2-binary`
- **Registry**: `jtayl22/mlflow-postgresql:2.17.2`

## 🔧 **Build Instructions**

```bash
# Build the image
docker build -t jtayl22/mlflow-postgresql:2.17.2 .

# Push to registry
docker push jtayl22/mlflow-postgresql:2.17.2

# Test locally
docker run --rm jtayl22/mlflow-postgresql:2.17.2 mlflow server --help
```

## 🚀 **Usage in Kubernetes**

```yaml
containers:
- name: mlflow
  image: jtayl22/mlflow-postgresql:2.17.2
  command: ["mlflow", "server"]
  args:
  - --backend-store-uri
  - postgresql://user:pass@host:5432/mlflow
```

## 🔄 **Update Process**

1. Update MLflow version in Dockerfile
2. Rebuild and push image
3. Update Ansible variables
4. Redeploy MLflow

## 📦 **Dependencies**
- MLflow 2.17.2
- psycopg2-binary (PostgreSQL adapter)
- Python 3.10 (from base image)

## 🐳 **Custom Docker Images**

This project includes custom Docker images for enhanced functionality:

### **MLflow with PostgreSQL Support**
- **Image**: `jtayl22/mlflow-postgresql:2.17.2`
- **Purpose**: MLflow with Model Registry using PostgreSQL backend
- **Source**: [`infrastructure/docker/mlflow-postgresql/`](infrastructure/docker/mlflow-postgresql/)

```bash
# Build custom MLflow image
cd infrastructure/docker/mlflow-postgresql/
./build.sh --push
```

### **Image Registry**
- **Public Images**: Docker Hub (`jtayl22/`)
- **Private Images**: Consider GitHub Container Registry for future images