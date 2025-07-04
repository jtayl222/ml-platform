# MLOps Infrastructure: Enterprise Secret Management

This directory contains the enterprise-grade secret management infrastructure for the MLOps platform, implementing industry best practices for credential distribution and team boundaries.

## Architecture Overview

```
infrastructure/
├── manifests/               # Individual sealed secrets (generated)
│   └── sealed-secrets/
│       ├── financial-ml/    # Production namespace secrets
│       └── financial-ml-dev/ # Development namespace secrets
├── packages/                # Team delivery packages (generated)
│   └── financial-ml/
│       ├── dev/             # Development environment
│       ├── production/      # Production environment
│       ├── secret-reference-template.yaml
│       └── README.md
└── *.tar.gz                # Timestamped delivery archives
```

## Team Workflow

### Infrastructure Team
1. **Generate secrets for development teams:**
   ```bash
   ./scripts/package-ml-secrets.sh financial-ml dev,production financial-team@company.com
   ```

2. **Deliver timestamped archive:**
   ```bash
   # Archive created automatically
   infrastructure/financial-ml-ml-secrets-20250704.tar.gz
   ```

### Application Teams
1. **Extract delivered package:**
   ```bash
   tar -xzf financial-ml-ml-secrets-20250704.tar.gz
   ```

2. **Apply secrets to environments:**
   ```bash
   kubectl apply -k dev/        # Development: financial-ml-dev namespace
   kubectl apply -k production/ # Production: financial-ml namespace
   ```

3. **Reference in applications:**
   ```yaml
   envFrom:
   - secretRef:
       name: ml-platform  # Same name across all environments
   imagePullSecrets:
   - name: ghcr
   ```

## Security Model

### Namespace Strategy
- **Development:** `{workflow}-dev` (e.g., `financial-ml-dev`)
- **Production:** `{workflow}` (e.g., `financial-ml`)
- **Staging:** `{workflow}-staging` (if needed)

### Secret Encryption
- Secrets encrypted using Sealed Secrets controller
- Each secret can only be decrypted in its target namespace
- Safe to store encrypted secrets in Git repositories

### Access Control
- Infrastructure team: Credential generation and rotation
- Application teams: Secret consumption via standard patterns
- Clear audit trail for all operations

## Benefits

### For Infrastructure Teams
- **Automated delivery:** No manual credential handoffs
- **Consistent patterns:** Same process for all teams
- **Security boundaries:** Encrypted secrets with namespace isolation
- **Operational efficiency:** Reduced support overhead

### For Application Teams
- **Self-service deployment:** Apply secrets independently
- **Environment consistency:** Same secret names across dev/prod
- **Simple integration:** Standard `envFrom` patterns
- **Fast onboarding:** Complete documentation included

### For Organizations
- **Security compliance:** Encrypted credentials with audit trails
- **Team scaling:** Clear boundaries between infrastructure and applications
- **Operational excellence:** Automated processes reduce human error
- **Cost efficiency:** Reduced infrastructure team bottlenecks

## Related Documentation

- **Implementation Guide:** `docs/enterprise-secret-management-mlops.md`
- **Script Documentation:** `scripts/README.md` (if available)
- **Application Examples:** Referenced GitHub repositories
- **Security Policies:** Internal security documentation

## Support

For questions about secret management or requesting new credentials:
- **Infrastructure Team:** infrastructure-team@company.com
- **Platform Issues:** File issues in this repository
- **Security Concerns:** security-team@company.com