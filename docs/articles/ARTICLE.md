# When Kubernetes CNI Goes Wrong: A Production MLOps Nightmare (And How We Fixed It)

**TL;DR**: Our entire model serving platform went down due to a 5-line ARP bug in Calico CNI. Here's how we debugged it with tcpdump, discovered GitHub issue #8689, and migrated to Cilium to save our production MLOps stack.

---

## The Crisis: When Model Serving Dies

Picture this: It's 2 AM, and your Slack is blowing up. Your Seldon Core v2 model deployments are timing out with cryptic `dial tcp 10.43.51.131:9004: i/o timeout` errors. The models that were working perfectly yesterday are now completely inaccessible.

This wasn't a hypothetical scenario—it was our reality after migrating from Flannel to Calico CNI in our production MLOps platform. What should have been a routine infrastructure upgrade turned into a multi-day debugging marathon that taught us everything about Kubernetes networking the hard way.

## Why We Needed to Migrate: The Flannel Limitations

Initially, our Kubernetes infrastructure, based on [K3s](https://github.com/k3s-io/k3s), utilized Flannel as the default CNI. However, when adopting Seldon Core v2 for our production MLOps pipelines—such as those demonstrated in our [financial MLOps platform](https://github.com/jtayl222/financial-mlops-pytorch)—we encountered critical limitations with Flannel.

### Intra-Pod Communication Issues

Seldon Core v2 requires robust intra-pod localhost communication to function correctly. The architecture demands internal communication among multiple containers within a single pod, such as the MLServer container, an Agent, and Rclone. Flannel’s networking model, unfortunately, blocked this intra-pod localhost communication, leading to failed health checks and the inability to accurately report server capacities.

This was especially impactful on our applications like:

* [iris-mlops-demo](https://github.com/jtayl222/iris-mlops-demo)
* [churn-prediction-argo-workflows](https://github.com/jtayl222/churn-prediction-argo-workflows)

Both applications rely heavily on smooth inter-container communication within pods.

## Diagnosing the Issue

We systematically tested and observed:

* External connectivity (cross-namespace, inter-pod): ✅ Worked fine.
* Intra-pod connectivity: ❌ Blocked.

Network analysis confirmed the Flannel backend (VXLAN mode) inherently blocked loopback interface traffic within pods.

```bash
kubectl logs mlserver-0 -c agent -n financial-ml | grep "connection refused"
# Output: ❌ FAILURE - dial tcp 127.0.0.1:9500: connect: connection refused
```

## Calico as the Chosen Solution

We identified [Calico](https://projectcalico.docs.tigera.io/) as the optimal alternative. Calico provided native intra-pod localhost support and advanced features required for our production workloads, including fine-grained Network Policies, improved security, and native observability.

### Calico’s Advantages

* **Native Localhost Communication:** Immediately resolved intra-pod connectivity issues, allowing Seldon Core v2’s multi-container architecture to operate as designed.
* **Advanced Network Policies:** Enhanced security and multi-tenancy features aligned with our enterprise security requirements.
* **Performance Optimization:** Eliminated unnecessary network hops, reducing latency.

## Lessons Learned from the Migration

### 1. CIDR Consistency Matters

Misalignment between pod CIDRs in K3s (`10.42.0.0/16`) and Calico’s IP pools (`10.244.0.0/16`) caused significant networking issues initially. Ensuring consistency resolved immediate connectivity problems.

### 2. Network Policy Transition

Calico defaults to a deny-all policy compared to Flannel’s permissive default-allow. Explicitly defining necessary Network Policies, especially for DNS resolution (port 53 UDP/TCP), became critical.

### 3. Integration with MetalLB

The move also coincided with adopting [MetalLB](https://metallb.universe.tf/) to solve dynamic IP challenges. MetalLB's LoadBalancer services provided stable IP endpoints, drastically improving operational reliability for services like MLflow and Grafana.

### Example of MetalLB Stability

```yaml
apiVersion: v1
kind: Service
metadata:
  name: mlflow
  annotations:
    metallb.universe.tf/loadBalancer-ips: 192.168.1.200
spec:
  type: LoadBalancer
  ports:
  - port: 5000
    targetPort: 5000
```

## The Migration Process

Our migration followed a carefully staged plan:

1. **Planning and Preparation:**

   * Environment setup on a staging cluster
   * Network CIDR and policy design

2. **Staging Deployment:**

   * Calico installation
   * Seldon Core functionality and performance validation

3. **Production Migration:**

   * Gradual replacement of Flannel with Calico
   * End-to-end ML pipeline testing

4. **Optimization:**

   * Calico performance tuning
   * Comprehensive monitoring setup with Prometheus and Grafana

## Automating and Securing the Migration

Automation via [Ansible](https://jeftaylo.medium.com/from-notebook-to-model-server-automating-mlops-with-ansible-mlflow-and-argo-workflows-bb54c440fc36) and [GitOps](https://jeftaylo.medium.com/mlflow-argo-workflows-and-kustomize-the-production-mlops-trinity-5bdb45d93f41) significantly reduced human error. Additionally, robust secret management ([detailed here](https://jeftaylo.medium.com/enterprise-secret-management-in-mlops-kubernetes-security-at-scale-a80875e73086)) ensured security at scale during the transition.

## Recommendations for Kubernetes Networking

* **Incorporate networking tests into CI/CD pipelines:** Automate CIDR and connectivity tests to detect regressions early.
* **Maintain clear, version-controlled infrastructure definitions:** Use tools like Ansible and Kustomize to manage changes systematically.
* **Invest in robust monitoring and observability:** Ensure quick detection and remediation of networking issues.

## Final Thoughts

Migrating from Flannel to Calico not only solved immediate networking issues but also prepared our infrastructure for robust, secure, and performant operation. This experience highlighted the importance of careful planning, automation, and adherence to platform engineering best practices. For those operating Kubernetes clusters, especially in performance-sensitive environments like [MLOps homelabs](https://github.com/jtayl222/ml-platform), selecting and managing the right CNI can significantly impact operational excellence and team productivity.

For more insights, you can explore my other Medium articles:

* [Accelerating MLOps with MLflow](https://jeftaylo.medium.com/accelerate-your-teams-mlops-capabilities-how-mlflow-fuels-scalable-and-efficient-machine-learning-b3349b2f2404)
* [Building a Fortune 500 MLOps Stack](https://jeftaylo.medium.com/building-an-mlops-homelab-architecture-and-tools-for-a-fortune-500-stack-08c5d5afa058)

Networking is foundational—never underestimate its critical role in Kubernetes success.
