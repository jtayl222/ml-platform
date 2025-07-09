# Article: "Migrating from Flannel to Calico CNI: Lessons from Production Kubernetes Networking Issues"

## Table of Contents

### 1. Introduction
- The evolution of CNI requirements in modern ML platforms
- Why Seldon Core v2 required Calico over Flannel
- Setting the stage: A production 5-node K3s cluster migration

### 2. The Problem: When CNI Migration Goes Wrong
- Symptom: `dial tcp 10.43.51.131:9004: i/o timeout` errors
- Model scheduling failures in Seldon Core v2
- The silent killer: CIDR configuration mismatches
- MetalLB LoadBalancer integration challenges with CNI changes

### 3. Root Cause Analysis
- **Technical Deep Dive:**
  - K3s default pod CIDR vs Calico IP pool configuration
  - Network policy behavioral differences between Flannel and Calico
  - Service discovery implications in multi-CNI environments
  - MetalLB IP pool allocation and CNI interaction
- **The Hidden Configuration Trap:**
  - Ansible role defaults vs inventory group variables
  - Template variable resolution order gotchas
  - Why `10.244.0.0/16` != `10.42.0.0/16` broke everything
  - MetalLB LoadBalancer service type conflicts with NodePort fallbacks

### 4. The Detective Work: Debugging Kubernetes Networking
- Using `kubectl exec` for network connectivity testing
- Analyzing pod-to-pod vs pod-to-service communication patterns
- Network policy troubleshooting in Calico environments
- The importance of DNS resolution testing (`nslookup kubernetes.default.svc.cluster.local`)

### 5. The Fix: Systematic CNI Configuration Alignment
- **Step 1:** CIDR Configuration Harmonization
- **Step 2:** Network Policy Migration Strategy  
- **Step 3:** MetalLB LoadBalancer Integration
- **Step 4:** Service Discovery Validation
- **Step 5:** Automated Testing Implementation

### 6. Platform vs Application Team Responsibilities
- Defining the separation of concerns in network policy management
- When platform teams should manage baseline policies
- How application teams can layer additional security requirements
- GitOps integration for network policy lifecycle management

### 7. Production Deployment Strategy
- Blue-green CNI migration approach
- Rollback planning and validation checkpoints
- Monitoring and alerting for CNI-related issues
- Documentation and knowledge transfer processes

### 8. Lessons Learned and Best Practices
- The critical importance of CIDR consistency across infrastructure components
- Why network policy testing should be part of CI/CD pipelines
- Platform engineering principles for CNI management
- The value of comprehensive infrastructure documentation

### 9. Tools and Automation
- Ansible playbook design patterns for CNI management
- MetalLB automation and IP pool management
- Custom validation scripts for network connectivity
- Integration with existing MLOps toolchains
- Monitoring and observability for Kubernetes networking

### 10. Conclusion
- Key takeaways for platform engineers
- The future of CNI in Kubernetes environments
- Building resilient ML infrastructure

## Key Bullet Points to Include

### Technical Details
- **CIDR Mismatch:** How `k3s_pod_cidr: "10.42.0.0/16"` in inventory conflicted with `calico_ipv4pool_cidr: "10.244.0.0/16"` in role defaults
- **Network Policy Gaps:** Calico's default-deny behavior vs Flannel's default-allow requiring explicit DNS resolution rules
- **Service Discovery:** The critical importance of allowing port 53 (UDP/TCP) to kube-system namespace
- **Template Variables:** How `{{ k3s_pod_cidr | default('10.42.0.0/16') }}` saved the day
- **MetalLB Integration:** LoadBalancer service type automation with `metallb_state` conditional logic
- **IP Pool Management:** MetalLB IP range allocation (192.168.1.200-250) and shared IP configuration

### Platform Engineering Insights
- **Infrastructure as Code:** Ansible role design patterns for multi-CNI support
- **GitOps Integration:** How sealed secrets and network policies fit into continuous deployment
- **Separation of Concerns:** Platform baseline vs application-specific network policies
- **LoadBalancer Strategy:** MetalLB bare-metal LoadBalancer vs NodePort service patterns
- **Documentation Strategy:** Living documentation that evolves with infrastructure

### Real-World Impact
- **Business Continuity:** Zero-downtime migration strategies for production ML workloads
- **Team Collaboration:** How platform and application teams coordinate during CNI changes
- **Cost Implications:** The hidden costs of CNI configuration errors in production
- **Security Considerations:** Network segmentation in multi-tenant ML environments

### Debugging Techniques
- **Network Connectivity Testing:** `kubectl run test-pod --image=busybox --rm -it --restart=Never -- nslookup`
- **Pod IP Analysis:** Using `kubectl get pods -o wide` to verify CIDR allocation
- **Service Discovery Validation:** Testing cross-namespace communication patterns
- **Network Policy Debugging:** `kubectl describe networkpolicy` troubleshooting workflows

### Automation and Tooling
- **Preservation Scripts:** `./scripts/preserve-uncommitted-changes.sh` for safe experimentation
- **Validation Automation:** Automated CIDR consistency checking in CI/CD
- **MetalLB Management:** Automated IP pool provisioning and LoadBalancer service configuration
- **Monitoring Integration:** Prometheus metrics for CNI health monitoring
- **Recovery Procedures:** Automated rollback scripts for failed CNI migrations

## Reference Documentation

**Note:** Include content from `docs/flannel-to-calico-migration-required.md` which documents the original migration decision and requirements analysis.