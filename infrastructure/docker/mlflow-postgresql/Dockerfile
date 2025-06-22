# Create a Dockerfile
FROM ghcr.io/mlflow/mlflow:v3.1.0

# Install PostgreSQL driver and authentication dependencies
RUN pip install psycopg2-binary boto3 mlflow[auth] && \
    apt-get update && apt-get install -y gettext && \
    rm -rf /var/lib/apt/lists/*

# Keep the same entrypoint
CMD ["mlflow", "server", "--help"]
