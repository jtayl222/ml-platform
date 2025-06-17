# Scripts Documentation

## Sealed Secrets Management

### create-all-sealed-secrets.sh
Creates all sealed secrets for the platform with environment variable support.

#### Usage:
```bash
# Use defaults (development)
./scripts/create-all-sealed-secrets.sh

# Use custom credentials
export MINIO_ACCESS_KEY="your-key"
export MINIO_SECRET_KEY="your-secret"
./scripts/create-all-sealed-secrets.sh
```

#### Environment Variables:
- `MINIO_ACCESS_KEY` - MinIO access key (default: minioadmin)
- `MINIO_SECRET_KEY` - MinIO secret key (default: minioadmin123)
- `GITHUB_USERNAME` - GitHub username for container registry
- `GITHUB_PAT` - GitHub Personal Access Token
- `GITHUB_EMAIL` - GitHub email address
