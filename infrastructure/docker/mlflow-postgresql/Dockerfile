# Create a Dockerfile
FROM ghcr.io/mlflow/mlflow:v2.17.2

# Install PostgreSQL driver
RUN pip install psycopg2-binary

# Keep the same entrypoint
CMD ["mlflow", "server", "--help"]
